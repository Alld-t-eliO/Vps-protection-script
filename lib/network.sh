ip_active_connections() {
    subsection "CONNECTED PUBLIC IPs"

    if [ -n "${SS_ESTABLISHED_FIXTURE:-}" ]; then
        connected_ips=$(
            awk 'NR > 1 {print $5}' "$SS_ESTABLISHED_FIXTURE" \
            | sed 's/^\[//; s/\]$//' \
            | sed 's/:[0-9]*$//' \
            | sort -u
        )
    elif command -v ss >/dev/null 2>&1; then
        connected_ips=$(
            ss -tn state established \
            | awk 'NR > 1 {print $5}' \
            | sed 's/^\[//; s/\]$//' \
            | sed 's/:[0-9]*$//' \
            | sort -u
        )
    else
        log_error "ss command is unavailable."
        return
    fi

    if [ -z "$connected_ips" ]; then
        log_info "No active remote TCP connections detected."
        return
    fi

    while read -r remote_ip; do
        log " - $remote_ip"
    done <<< "$connected_ips"
}


network_listening_ports() {
    subsection "LISTENING PORTS"

    if [ -n "${SS_LISTEN_FIXTURE:-}" ]; then
        cat "$SS_LISTEN_FIXTURE" | append_output
    elif command -v ss >/dev/null 2>&1; then
        ss -tulpn 2>/dev/null | append_output
    else
        log_error "ss command is unavailable."
        return
    fi
}


check_network() {
    section "NETWORK"

    network_listening_ports
    ip_active_connections
}
