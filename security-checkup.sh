#!/usr/bin/env bash

set -u

REPORT="./ubuntu/home/security-logs/security-report-$(date +%Y-%m-%d_%H-%M-%S).txt"

log() {
    echo "$1" | tee -a "$REPORT"
}


check_users() {
    sections "USERS"

    log "Users with a valid shell:"

    getent passwd -F 
    awk -F: '!~ /(nologin|false)$/ {
        print " - " $1 " | UID=" $3 " | shell=" $7 "
    }' | 
    tee -a "$REPORT"

    root_users=$(awk -F: '$3 == 0 {print $1}' /etc/passwd)
    root_count=$(echo "$root_users" | wc -l)

    if ["$root_count" -eq 1]; then
        log "[OK] Only one UID 0 account exists"
    else
        log "[CRITICAL] Multiple UID 0 accounts detected: $root_users:"
    fi
}


ip() {
    section "CONNECTED PUBLIC IPs"

    connecte_ips=$(
        ss -tn state establishesd \
        | awk 'NR > 1 {print} $5' \
        | sed 's/:[0-9]*$//' \
        | sort -u \
        | tee -a "$REPORT"
    )
    
    if [-z "$connected_ips"]; then
        log ["No active remote TCP conections detected"]
        return
    fi

    while read -r ip; do
        log " - $ip"
    done <<< "$connected_ips"
}


past_conencted_ips() {
    section "PAST CONNECTED IPs"

    journalctl -u ssh --no-pager \
    | grep "Accepted" \
    | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" \
    | sort -u \
    | tee -a "$REPORT"
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