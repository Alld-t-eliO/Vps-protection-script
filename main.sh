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
    echo "  --quiet        Suppress terminal output while keeping scan artifacts"
    echo "  --json-only    Print only findings.json to stdout after the scan"
    echo "  --no-color     Disable ANSI colors"
    echo "  --config       Load a custom config file"
    echo "  --profile      Load an audit profile from profiles/<name>.conf"
    echo "  --plugin       Run one plugin from plugins/<name>.sh"
    echo "  --plugins      Run all plugins from plugins/"
    echo "  --save-baseline Save current findings as a signed baseline"
    echo "  --compare-baseline Compare current findings with the signed baseline"
    echo "  --format       Optional export format: text or jsonl"
    echo "  --syslog       Export findings to syslog with logger"
    echo "  --webhook-url  POST findings.json to an HTTP webhook"
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
        --plugins)
            run_all_plugins
            ;;
        --plugin:*)
            run_plugin "${option#--plugin:}"
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
            --save-baseline)
                SAVE_BASELINE=1
                ;;
            --compare-baseline)
                COMPARE_BASELINE=1
                ;;
            --syslog)
                SYSLOG_EXPORT=1
                ;;
            --quiet)
                QUIET_MODE=1
                ;;
            --json-only)
                JSON_ONLY=1
                QUIET_MODE=1
                ;;
            --no-color)
                RED=""
                CYAN=""
                PURPLE=""
                GREEN=""
                YELLOW=""
                RESET=""
                ;;
            --config)
                shift
                if [ "$#" -eq 0 ]; then
                    echo "Missing value for --config" >&2
                    exit 2
                fi
                CONFIG_FILE="$1"
                # shellcheck source=/dev/null
                source "$CONFIG_FILE"
                ;;
            --config=*)
                CONFIG_FILE="${1#--config=}"
                # shellcheck source=/dev/null
                source "$CONFIG_FILE"
                ;;
            --profile)
                shift
                if [ "$#" -eq 0 ]; then
                    echo "Missing value for --profile" >&2
                    exit 2
                fi
                load_profile "$1" || exit 2
                ;;
            --profile=*)
                load_profile "${1#--profile=}" || exit 2
                ;;
            --plugin)
                shift
                if [ "$#" -eq 0 ]; then
                    echo "Missing value for --plugin" >&2
                    exit 2
                fi
                SCAN_OPTIONS+=("--plugin:$1")
                ;;
            --plugin=*)
                SCAN_OPTIONS+=("--plugin:${1#--plugin=}")
                ;;
            --plugins)
                SCAN_OPTIONS+=("--plugins")
                ;;
            --format)
                shift
                if [ "$#" -eq 0 ]; then
                    echo "Missing value for --format" >&2
                    exit 2
                fi
                FORMAT="$1"
                [ "$FORMAT" = "jsonl" ] && QUIET_MODE=1
                ;;
            --format=*)
                FORMAT="${1#--format=}"
                [ "$FORMAT" = "jsonl" ] && QUIET_MODE=1
                ;;
            --webhook-url)
                shift
                if [ "$#" -eq 0 ]; then
                    echo "Missing value for --webhook-url" >&2
                    exit 2
                fi
                WEBHOOK_URL="$1"
                ;;
            --webhook-url=*)
                WEBHOOK_URL="${1#--webhook-url=}"
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
        if [ -n "$PROFILE_SCANS" ]; then
            # shellcheck disable=SC2206
            SCAN_OPTIONS=($PROFILE_SCANS)
        else
            banner
            usage
            exit 0
        fi
    fi

    if [ "${#SCAN_OPTIONS[@]}" -eq 0 ]; then
        banner
        usage
        exit 0
    fi

    load_plugins

    if [ "$QUIET_MODE" -eq 0 ]; then
        banner
    fi
    header

    for option in "${SCAN_OPTIONS[@]}"; do
        run_option "$option"
    done

    finalize_scan
}


main "$@"
