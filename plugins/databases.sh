check_databases() {
    section "PLUGIN: DATABASE EXPOSURE"

    listeners=$(ss -ltnp 2>/dev/null || true)

    if [ -z "$listeners" ]; then
        log_info "No TCP listener data available."
        return
    fi

    echo "$listeners" | grep -E ':(3306|5432|6379|27017)\b' | append_output || log_ok "No common database ports detected on TCP listeners."

    echo "$listeners" | grep -E '0\.0\.0\.0:(3306|5432|6379|27017)|\[::\]:(3306|5432|6379|27017)' >/dev/null 2>&1 \
        && log_critical "Database service appears exposed on all interfaces." "Bind databases to localhost/private interfaces and restrict access with firewall rules." \
        || log_ok "No common database listener appears bound to all interfaces."
}
