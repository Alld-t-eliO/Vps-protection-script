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