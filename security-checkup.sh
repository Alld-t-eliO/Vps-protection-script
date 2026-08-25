#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/users.sh"
source "$SCRIPT_DIR/lib/network.sh"
source "$SCRIPT_DIR/lib/ssh.sh"
source "$SCRIPT_DIR/lib/firewall.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/services.sh"
source "$SCRIPT_DIR/lib/updates.sh"
source "$SCRIPT_DIR/lib/filesystem.sh"

header() {
    section "VPS SECURITY CHECKUP"

    log "Date: $(date)"
    log "Hostname: $(hostname)"
    log "Kernel: $(uname -r)"
    log "Uptime: $(uptime -p)"
}

main() {
    header

    check_users
    check_network
    check_ssh
    check_ssh_activity
    check_firewall
    check_docker
    check_services_processes
    check_updates
    check_filesystem

    section "END OF CHECKUP"

    log_ok "Security checkup completed."
    log "Report saved to: $REPORT"
}

main