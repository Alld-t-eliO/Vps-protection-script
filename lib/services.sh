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