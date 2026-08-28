check_unattended_upgrades() {
    section "PLUGIN: UNATTENDED UPGRADES"

    if command -v apt >/dev/null 2>&1; then
        dpkg -l unattended-upgrades 2>/dev/null | append_output || log_warning "unattended-upgrades is not installed." "Install unattended-upgrades or document manual patch cadence."
        systemctl is-enabled unattended-upgrades 2>/dev/null | append_output || true
    else
        log_info "APT is unavailable; unattended-upgrades does not apply."
    fi
}
