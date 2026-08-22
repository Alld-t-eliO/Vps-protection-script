#!/usr/bin/env bash

set -u

REPORT="$HOME/security-logs/security-report-$(date +%Y-%m-%d_%H-%M-%S).txt"

mkdir -p "$HOME/security-logs"


log() {
    echo "$1" | tee -a "$REPORT"
}


section() {
    log ""
    log "=============================="
    log " $1"
    log "=============================="
}


header() {
    log "=============================="
    log "    VPS SECURITY CHECKUP"
    log "=============================="
    log ""
    log "Date: $(date)"
    log "Hostname: $(hostname)"
    log "Kernel: $(uname -r)"
    log "Uptime: $(uptime -p)"
}


check_users() {
    section "USERS"

    log "Users with a valid shell:"

    getent passwd \
    | awk -F: '$7 !~ /(nologin|false)$/ {
        print " - " $1 " | UID=" $3 " | shell=" $7
    }' \
    | tee -a "$REPORT"

    root_users=$(awk -F: '$3 == 0 {print $1}' /etc/passwd)
    root_count=$(echo "$root_users" | wc -l)

    if [ "$root_count" -eq 1 ]; then
        log "[OK] Only one UID 0 account exists"
    else
        log "[CRITICAL] Multiple UID 0 accounts detected: $root_users"
    fi
}


ip_active_connections() {
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



ssh_configuration() {
    section "SSH CONFIGURATION"

    ssh_config=$(sshd -T 2>/dev/null)

    root_login=$(
        echo "$ssh_config" \
        | awk '$1 == "permitrootlogin" {print $2}'
    )

    password_auth=$(
        echo "$ssh_config" \
        | awk '$1 == "passwordauthentication" {print $2}'
    )

    log "PermitRootLogin: $root_login"
    log "PasswordAuthentication: $password_auth"

    if [ -z "$root_login" ]; then
        log "[ERROR] Unable to determine PermitRootLogin"
    elif [ "$root_login" = "no" ]; then
        log "[OK] Root login is disabled"
    else
        log "[CRITICAL] Root SSH login is not fully disabled: $root_login"
    fi

    if [ -z "$password_auth" ]; then
        log "[ERROR] Unable to determine PasswordAuthentication"
    elif [ "$password_auth" = "no" ]; then
        log "[OK] Password authentication is disabled"
    else
        log "[CRITICAL] SSH password authentication is enabled"
    fi
}


ssh_fail2ban() {
    section "FAIL2BAN SSH"

    if ! command -v fail2ban-client >/dev/null 2>&1; then
        log "[INFO] Fail2Ban is not installed"
        return
    fi

    if ! systemctl is-active --quiet fail2ban; then
        log "[WARNING] Fail2Ban is not running"
        return
    fi

    fail2ban-client status sshd \
    | tee -a "$REPORT"
}


ssh_current_connections() {
    section "CURRENT SSH CONNECTIONS"

    connections=$(
        ss -tnp 2>/dev/null \
        | grep ssh || true
    )

    if [ -z "$connections" ]; then
        log "No current SSH connections detected."
        return
    fi

    echo "$connections" \
    | tee -a "$REPORT"
}

firewall_status() {
    section "FIREWALL STATUS"

    if ! command -v ufw >/dev/null 2>&1; then
        log "[CRITIC] UFW no installed."
        return
    fi 

    if ! ufw status | grep -q "Status: active"; then
        log "[CRITIC] UFW not activated"
        return
    fi

    log "[OK] UFW firewall is active."

    ufw status verbose \
    | tee -a "$REPORT"
}


firewall_rules() {
    section "FIREWALL RULES"

    ufw status numbered \
    | tee -a "$REPORT"
}


network_listening_ports() {
    section "LISTENING PORTS"

    ss -tulpn \
    | tee -a "REPORT"
}


check_ip() {
    section "NETWORK / IP"

    ip_active_connections
}


check_ssh() {
    section "SSH"

    ssh_configuration
    ssh_fail2ban
}


ssh_successful_connections() {
    section "SUCCESSFUL SSH CONNECTIONS"

    journalctl -u ssh --no-pager -q \
    | grep "Accepted" \
    | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
    | sort \
    | uniq -c \
    | sort -nr \
    | tee -a "$REPORT"
}


ssh_failed_attempts() {
    section "FAILED SSH ATTEMPTS - LAST 24H"

    journalctl -u ssh --since "24 hours ago" --no-pager -q \
    | grep -E "Failed password|Invalid user|authentication failure" \
    | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
    | sort \
    | uniq -c \
    | sort -nr \
    | tee -a "$REPORT"
}


check_ssh_activity() {
    section "SSH ACTIVITY"

    ssh_successful_connections
    ssh_failed_attempts
    ssh_current_connections
}


check_firewall() {
    section "FIREWALL ACTIVITY/STATES"

    firewall_status
    firewall_rules
    network_listening_ports
}


main() {
    log ""

    header
    check_users
    check_ip
    check_ssh
    check_ssh_activity
    check_firewall

    log ""
    log "Report saved to: $REPORT"
}


main
