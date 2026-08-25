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