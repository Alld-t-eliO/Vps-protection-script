#!/usr/bin/env bash

set -u


RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'


REPORT="$HOME/security-logs/security-report-$(date +%Y-%m-%d_%H-%M-%S).txt"

mkdir -p "$HOME/security-logs"


log() {
    echo -e "${CYAN}$1${RESET}"
    echo "$1" >> "$REPORT"
}


log_info() {
    echo -e "${CYAN}[INFO] $1${RESET}"
    echo "[INFO] $1" >> "$REPORT"
}


log_ok() {
    echo -e "${GREEN}[OK] $1${RESET}"
    echo "[OK] $1" >> "$REPORT"
}


log_warning() {
    echo -e "${YELLOW}[WARNING] $1${RESET}"
    echo "[WARNING] $1" >> "$REPORT"
}


log_error() {
    echo -e "${RED}[ERROR] $1${RESET}"
    echo "[ERROR] $1" >> "$REPORT"
}


log_critical() {
    echo -e "${RED}[CRITICAL] $1${RESET}"
    echo "[CRITICAL] $1" >> "$REPORT"
}


section() {
    echo ""

    echo -e "${PURPLE}==============================${RESET}"
    echo -e "${PURPLE} $1${RESET}"
    echo -e "${PURPLE}==============================${RESET}"

    {
        echo ""
        echo "=============================="
        echo " $1"
        echo "=============================="
    } >> "$REPORT"
}


header() {
    section "VPS SECURITY CHECKUP"

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
        log_ok "Only one UID 0 account exists."
    else
        log_critical "Multiple UID 0 accounts detected: $root_users"
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
        log_info "No active remote TCP connections detected."
        return
    fi

    while read -r remote_ip; do
        [ -n "$remote_ip" ] && log " - $remote_ip"
    done <<< "$connected_ips"
}


network_listening_ports() {
    section "LISTENING PORTS"

    ss -tulpn \
    | tee -a "$REPORT"
}


check_ip() {
    section "NETWORK / IP"

    ip_active_connections
}


ssh_configuration() {
    section "SSH CONFIGURATION"

    if ! command -v sshd >/dev/null 2>&1; then
        log_error "sshd command not found."
        return
    fi

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
        log_error "Unable to determine PermitRootLogin."
    elif [ "$root_login" = "no" ]; then
        log_ok "Root SSH login is disabled."
    else
        log_critical "Root SSH login is not fully disabled: $root_login"
    fi

    if [ -z "$password_auth" ]; then
        log_error "Unable to determine PasswordAuthentication."
    elif [ "$password_auth" = "no" ]; then
        log_ok "SSH password authentication is disabled."
    else
        log_critical "SSH password authentication is enabled."
    fi
}


ssh_fail2ban() {
    section "FAIL2BAN SSH"

    if ! command -v fail2ban-client >/dev/null 2>&1; then
        log_info "Fail2Ban is not installed."
        return
    fi

    if ! systemctl is-active --quiet fail2ban; then
        log_warning "Fail2Ban is not running."
        return
    fi

    log_ok "Fail2Ban is running."

    fail2ban-client status sshd \
    | tee -a "$REPORT"
}


ssh_successful_connections() {
    section "SUCCESSFUL SSH CONNECTIONS"

    connections=$(
        journalctl -u ssh --no-pager -q \
        | grep "Accepted" \
        | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
        | sort \
        | uniq -c \
        | sort -nr || true
    )

    if [ -z "$connections" ]; then
        log_info "No successful SSH connections found in available logs."
        return
    fi

    echo "$connections" \
    | tee -a "$REPORT"
}


ssh_failed_attempts() {
    section "FAILED SSH ATTEMPTS - LAST 24H"

    attempts=$(
        journalctl -u ssh --since "24 hours ago" --no-pager -q \
        | grep -E "Failed password|Invalid user|authentication failure" \
        | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
        | sort \
        | uniq -c \
        | sort -nr || true
    )

    if [ -z "$attempts" ]; then
        log_ok "No failed SSH attempts detected in the last 24 hours."
        return
    fi

    log_warning "Failed SSH attempts detected."

    echo "$attempts" \
    | tee -a "$REPORT"
}


ssh_current_connections() {
    section "CURRENT SSH CONNECTIONS"

    connections=$(
        ss -tnp 2>/dev/null \
        | grep ssh || true
    )

    if [ -z "$connections" ]; then
        log_info "No current SSH connections detected."
        return
    fi

    echo "$connections" \
    | tee -a "$REPORT"
}


check_ssh() {
    section "SSH"

    ssh_configuration
    ssh_fail2ban
}


check_ssh_activity() {
    section "SSH ACTIVITY"

    ssh_successful_connections
    ssh_failed_attempts
    ssh_current_connections
}


firewall_status() {
    section "FIREWALL STATUS"

    if ! command -v ufw >/dev/null 2>&1; then
        log_critical "UFW is not installed."
        return
    fi

    if ! ufw status | grep -q "Status: active"; then
        log_critical "UFW is not active."
        return
    fi

    log_ok "UFW firewall is active."

    ufw status verbose \
    | tee -a "$REPORT"
}


firewall_rules() {
    section "FIREWALL RULES"

    if ! command -v ufw >/dev/null 2>&1; then
        log_warning "UFW unavailable."
        return
    fi

    ufw status numbered \
    | tee -a "$REPORT"
}


check_firewall() {
    section "FIREWALL / NETWORK SECURITY"

    firewall_status
    firewall_rules
    network_listening_ports
}


docker_available() {
    command -v docker >/dev/null 2>&1 \
    && docker info >/dev/null 2>&1
}


docker_status() {
    section "DOCKER STATUS"

    if ! command -v docker >/dev/null 2>&1; then
        log_info "Docker is not installed."
        return
    fi

    if systemctl is-active --quiet docker; then
        log_ok "Docker is active."
    else
        log_warning "Docker is inactive."
    fi

    systemctl is-active docker \
    | tee -a "$REPORT"
}


docker_containers() {
    section "DOCKER CONTAINERS"

    if ! docker_available; then
        log_info "Docker unavailable. Skipping container check."
        return
    fi

    docker ps -a \
        --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" \
    | tee -a "$REPORT"
}


docker_exposed_ports() {
    section "DOCKER EXPOSED PORTS"

    if ! docker_available; then
        log_warning "Docker unavailable."
        return
    fi

    docker ps \
        --format "table {{.Names}}\t{{.Ports}}" \
    | tee -a "$REPORT"
}


docker_privileged_containers() {
    section "DOCKER PRIVILEGED CONTAINERS"

    if ! docker_available; then
        log_warning "Docker unavailable."
        return
    fi

    containers=$(docker ps -a --format '{{.Names}}')

    if [ -z "$containers" ]; then
        log_info "No Docker containers found."
        return
    fi

    while read -r container; do

        privileged=$(
            docker inspect \
                --format '{{.HostConfig.Privileged}}' \
                "$container"
        )

        if [ "$privileged" = "true" ]; then
            log_warning "$container is running in privileged mode."
        else
            log_ok "$container is not privileged."
        fi

    done <<< "$containers"
}


docker_restart_policies() {
    section "DOCKER RESTART POLICIES"

    if ! docker_available; then
        log_warning "Docker unavailable."
        return
    fi

    containers=$(docker ps -aq)

    if [ -z "$containers" ]; then
        log_info "No Docker containers found."
        return
    fi

    docker inspect \
        --format '{{.Name}} -> {{.HostConfig.RestartPolicy.Name}}' \
        $containers \
    | tee -a "$REPORT"
}


docker_mounts() {
    section "DOCKER MOUNTS"

    if ! docker_available; then
        log_warning "Docker unavailable."
        return
    fi

    containers=$(docker ps -aq)

    if [ -z "$containers" ]; then
        log_info "No Docker containers found."
        return
    fi

    docker inspect \
        --format '{{.Name}} -> {{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' \
        $containers \
    | tee -a "$REPORT"
}


docker_users() {
    section "DOCKER CONTAINER USERS"

    if ! docker_available; then
        log_warning "Docker unavailable."
        return
    fi

    containers=$(docker ps -a --format '{{.Names}}')

    if [ -z "$containers" ]; then
        log_info "No Docker containers found."
        return
    fi

    while read -r container; do

        user=$(
            docker inspect \
                --format '{{.Config.User}}' \
                "$container"
        )

        if [ -z "$user" ]; then
            log_warning "$container uses the image default user (possibly root)."
        elif [ "$user" = "root" ] || [ "$user" = "0" ]; then
            log_warning "$container is configured to run as root."
        else
            log_ok "$container runs as user: $user"
        fi

    done <<< "$containers"
}


check_docker() {
    section "DOCKER"

    docker_status
    docker_containers
    docker_exposed_ports
    docker_privileged_containers
    docker_restart_policies
    docker_mounts
    docker_users
}


services_running() {
    section "RUNNING SERVICES"

    systemctl \
        --type=service \
        --state=running \
        --no-pager \
    | tee -a "$REPORT"
}


services_enabled() {
    section "ENABLED SERVICES"

    systemctl list-unit-files \
        --type=service \
        --state=enabled \
        --no-pager \
    | tee -a "$REPORT"
}


services_failed() {
    section "FAILED SERVICES"

    failed_services=$(
        systemctl --failed \
            --type=service \
            --no-pager \
            --no-legend
    )

    if [ -z "$failed_services" ]; then
        log_ok "No failed services detected."
        return
    fi

    log_warning "Failed services detected:"

    echo "$failed_services" \
    | tee -a "$REPORT"
}


processes_root() {
    section "ROOT PROCESSES"

    ps -eo user,pid,ppid,%cpu,%mem,comm \
    | awk 'NR == 1 || $1 == "root"' \
    | tee -a "$REPORT"
}


processes_top_cpu() {
    section "TOP CPU PROCESSES"

    ps -eo pid,user,%cpu,%mem,comm \
        --sort=-%cpu \
    | head -n 11 \
    | tee -a "$REPORT"
}


processes_top_memory() {
    section "TOP MEMORY PROCESSES"

    ps -eo pid,user,%cpu,%mem,comm \
        --sort=-%mem \
    | head -n 11 \
    | tee -a "$REPORT"
}


check_services_processes() {
    section "SERVICES / PROCESSES"

    services_running
    services_enabled
    services_failed
    processes_root
    processes_top_cpu
    processes_top_memory
}


packages_updates_available() {
    section "AVAILABLE PACKAGE UPDATES"

    updates=$(
        apt list --upgradable 2>/dev/null \
        | tail -n +2
    )

    if [ -z "$updates" ]; then
        log_ok "No package updates available."
        return
    fi

    count=$(echo "$updates" | wc -l)

    log_warning "$count package update(s) available."

    echo "$updates" \
    | tee -a "$REPORT"
}


packages_security_updates() {
    section "SECURITY UPDATES"

    security_updates=$(
        apt list --upgradable 2>/dev/null \
        | grep -i security || true
    )

    if [ -z "$security_updates" ]; then
        log_ok "No security updates detected."
        return
    fi

    count=$(echo "$security_updates" | wc -l)

    log_warning "$count security update(s) available."

    echo "$security_updates" \
    | tee -a "$REPORT"
}


system_reboot_required() {
    section "REBOOT REQUIRED"

    if [ -f /var/run/reboot-required ]; then
        log_warning "System reboot is required."

        if [ -f /var/run/reboot-required.pkgs ]; then
            log "Packages requiring reboot:"

            cat /var/run/reboot-required.pkgs \
            | tee -a "$REPORT"
        fi
    else
        log_ok "No reboot required."
    fi
}


check_updates() {
    section "UPDATES / PACKAGES"

    packages_updates_available
    packages_security_updates
    system_reboot_required
}


filesystem_world_writable() {
    section "WORLD-WRITABLE FILES"

    files=$(
        find / -xdev -type f -perm -0002 2>/dev/null
    )

    if [ -z "$files" ]; then
        log_ok "No world-writable files detected."
        return
    fi

    count=$(echo "$files" | wc -l)

    log_warning "$count world-writable file(s) detected."

    echo "$files" \
    | tee -a "$REPORT"
}


filesystem_suid_sgid() {
    section "SUID / SGID FILES"

    files=$(
        find / -xdev -type f \
        \( -perm -4000 -o -perm -2000 \) \
        2>/dev/null
    )

    if [ -z "$files" ]; then
        log_ok "No SUID/SGID files detected."
        return
    fi

    log_info "SUID/SGID files detected for review:"

    echo "$files" \
    | tee -a "$REPORT"
}


filesystem_sensitive_permissions() {
    section "SENSITIVE FILE PERMISSIONS"

    files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/group"
        "/etc/gshadow"
        "/etc/ssh/sshd_config"
    )

    for file in "${files[@]}"; do

        if [ ! -e "$file" ]; then
            log_warning "$file does not exist."
            continue
        fi

        permissions=$(stat -c "%a" "$file")
        owner=$(stat -c "%U:%G" "$file")

        log "$file -> permissions=$permissions owner=$owner"
    done
}


check_filesystem() {
    section "FILESYSTEM / PERMISSIONS"

    filesystem_world_writable
    filesystem_suid_sgid
    filesystem_sensitive_permissions
}


main() {
    log ""

    header

    check_users
    check_ip
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
