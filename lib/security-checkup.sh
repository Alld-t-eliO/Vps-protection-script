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

check_docker() {
    section "DOCKER"

    docker_status
    docker_containers
    docker_exposed_ports
    docker_privileged_containers
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