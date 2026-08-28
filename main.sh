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

TOOL_NAME="VPS Security Checkup"
VERSION="1.1.0"
GITHUB_NAME="Aegon"


banner() {
    echo -e "${PURPLE}"

    cat << 'EOF'
____   ____    .__    _________
\   \ /   /_ __|  |  /   _____/ ____ _____    ____
 \   Y   /  |  \  |  \_____  \_/ ___\\__  \  /    \
  \     /|  |  /  |__/        \  \___ / __ \|   |  \
   \___/ |____/|____/_______  /\___  >____  /___|  /
                            \/     \/     \/     \/

      SECURITY CHECKUP

EOF

    echo -e "${CYAN}${TOOL_NAME}${RESET}"
    echo -e "${CYAN}Version : ${VERSION}${RESET}"
    echo -e "${CYAN}GitHub  : ${GITHUB_NAME}${RESET}"
    echo -e "${CYAN}Scan dir: ${SCAN_DIR}${RESET}"
    echo ""
}


header() {
    section "VPS SECURITY CHECKUP"

    log "Date: $(date)"
    log "Hostname: $(hostname)"
    log "Kernel: $(uname -r)"
    log "Architecture: $(uname -m)"
    log "Uptime: $(uptime -p 2>/dev/null || uptime)"
}


usage() {
    echo ""
    echo -e "${PURPLE}Usage:${RESET}"
    echo ""
    echo "  $0 [OPTIONS]"
    echo ""
    echo -e "${PURPLE}Available scans:${RESET}"
    echo ""
    echo "  --all          Run complete security checkup"
    echo "  --users        Scan users and UID configuration"
    echo "  --network      Scan network connections and listening ports"
    echo "  --ssh          Scan SSH configuration and activity"
    echo "  --firewall     Scan UFW firewall configuration"
    echo "  --docker       Scan Docker configuration and containers"
    echo "  --services     Scan system services and processes"
    echo "  --updates      Scan available package/security updates"
    echo "  --filesystem   Scan filesystem and sensitive permissions"
    echo ""
    echo "  --strict       Exit with code 1 if warning, error or critical findings exist"
    echo "  --output-dir   Write scan artifacts under a custom directory"
    echo "  --compare-last Compare findings with the previous scan in the output directory"
    echo ""
    echo "  -h, --help     Show this help"
    echo ""
    echo -e "${PURPLE}Examples:${RESET}"
    echo ""
    echo "  sudo $0 --all"
    echo "  sudo $0 --ssh"
    echo "  sudo $0 --docker --firewall"
    echo "  sudo $0 --ssh --network --users"
    echo "  sudo $0 --all --strict --compare-last"
    echo "  sudo $0 --all --output-dir /var/log/vps-security-scans"
    echo ""
}


scan_all() {
    check_users
    check_network
    check_ssh
    check_ssh_activity
    check_firewall
    check_docker
    check_services_processes
    check_updates
    check_filesystem
}


run_option() {
    option="$1"

    case "$option" in
        --all)
            scan_all
            ;;
        --users)
            check_users
            ;;
        --network)
            check_network
            ;;
        --ssh)
            check_ssh
            check_ssh_activity
            ;;
        --firewall)
            check_firewall
            ;;
        --docker)
            check_docker
            ;;
        --services)
            check_services_processes
            ;;
        --updates)
            check_updates
            ;;
        --filesystem)
            check_filesystem
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $option"
            usage
            ;;
    esac
}


main() {
    if [ "$#" -eq 0 ]; then
        banner
        usage
        exit 0
    fi

    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        banner
        usage
        exit 0
    fi

    SCAN_OPTIONS=()

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --strict)
                STRICT_MODE=1
                ;;
            --compare-last)
                COMPARE_LAST=1
                ;;
            --output-dir)
                shift
                if [ "$#" -eq 0 ]; then
                    echo "Missing value for --output-dir" >&2
                    exit 2
                fi
                configure_output_dir "$1"
                ;;
            --output-dir=*)
                configure_output_dir "${1#--output-dir=}"
                ;;
            *)
                SCAN_OPTIONS+=("$1")
                ;;
        esac

        shift
    done

    if [ "${#SCAN_OPTIONS[@]}" -eq 0 ]; then
        banner
        usage
        exit 0
    fi

    banner
    header

    for option in "${SCAN_OPTIONS[@]}"; do
        run_option "$option"
    done

    finalize_scan
}


main "$@"
