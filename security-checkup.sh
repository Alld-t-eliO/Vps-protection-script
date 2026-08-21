#!/usr/bin/env bash

set -u

REPORT="<YOUR PATH>/security-logs/security-report-$(date +%Y-%m-%d_%H-%M-%S).txt"

log() {
    echo "$1" | tee -a "$REPORT"
}


ip() {
    section "CONNECTED PUBLIC IPs"

    connected_ips=$(
        ss -tn state established \
        | awk 'NR > 1 {print $5}' \
        | sed 's/^\[//; s/\]$//' \
        | sed 's/:[0-9]*$//' \
        | sort -u
    )

    if [ -z "$connected_ips" ]; then
        log "No active remote TCP connections detected."
        return
    fi

    while read -r remote_ip; do
        log " - $remote_ip"
    done <<< "$connected_ips"
}


check_ssh () {
    section "SSHH CONFIGURATION"

    ssh_config=$(sshd -T 2>/dev/null)

    root_login=$(echo "ssh_config"\
        | awk '$1 == "passwordauthentification" {print $2}')

    password_auth=$(echo "$ssh_config" \
        | awk '$1 == "passwordauthentification" {print $2}')

    log "PermitRootLogin: $root_login"
    log "PasswordAuthentification: $password_auth"

    if [ "$root_login" = "no" ]; then
        log "[OK] Root login is disabled"
    else
        log "[CRITICAL] Root SSH login is not fully disabled"
    fi

    if [ "$password_auth" = "no" ]; then
        log "[OK] Password authentication is disabled"
    else
        log "[CRITICAL] SSH password authentication is enabled"
    fi
}


ssh_ips() {
    section "RECENT SSH IPs"

    journalctl -u ssh --since "24 hours ago" --no-pager \
    | grep -E "Accepted|Failed password|Invalid user" \
    | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
    | sort \
    | uniq -c \
    | sort -nr \
    | tee -a "$REPORT"
}


past_connected_ips() {
    section "PAST CONNECTED IPs"

    journalctl -u ssh --no-pager \
    | grep "Accepted" \
    | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
    | sort -u \
    | tee -a "$REPORT"
}


check_users() {
    section "USERS"

    log "Users with a valid shell:"

    getent passwd |
    awk -F: '$7 !~ /(nologin|false)$/ {
        print " - " $1 " | UID=" $3 " | shell=" $7
    }' |
    tee -a "$REPORT"

    root_users=$(awk -F: '$3 == 0 {print $1}' /etc/passwd)
    root_count=$(echo "$root_users" | wc -l)

    if [ "$root_count" -eq 1 ]; then
        log "[OK] Only one UID 0 account exists"
    else
        log "[CRITICAL] Multiple UID 0 accounts detected: $root_users"
    fi
}


header() {
    log "=============================="
    log "    VPS SECURITY CHECKUP"
    log "=============================="
    log ""
    log "Date: $(date)"
    log "hostname: $(hostname)"
    log "Kernel: $(uname -r)"
    log "uptime: $(uptime -p)" 
}


header
check_users
check_network
check_ssh
ip
