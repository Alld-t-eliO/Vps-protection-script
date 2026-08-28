check_users() {
    section "USERS"

    log "Users with a valid shell:"

    getent passwd \
    | awk -F: '$7 !~ /(nologin|false)$/ {
        print " - " $1 " | UID=" $3 " | shell=" $7
    }' \
    | append_output

    root_users=$(awk -F: '$3 == 0 {print $1}' /etc/passwd)
    root_count=$(echo "$root_users" | wc -l)

    if [ "$root_count" -eq 1 ]; then
        log_ok "Only one UID 0 account exists."
    else
        log_critical "Multiple UID 0 accounts detected: $root_users" "Keep only root with UID 0 unless there is a documented break-glass account."
    fi

    subsection "SUDO ACCESS"

    if getent group sudo >/dev/null 2>&1; then
        getent group sudo | append_output
    elif getent group wheel >/dev/null 2>&1; then
        getent group wheel | append_output
    else
        log_info "No sudo or wheel group found."
    fi

    nopasswd=$(grep -R "NOPASSWD" /etc/sudoers /etc/sudoers.d 2>/dev/null || true)
    if [ -n "$nopasswd" ]; then
        echo "$nopasswd" | append_output
        log_warning "NOPASSWD sudo rules detected." "Remove NOPASSWD unless it is required for a tightly scoped automation command."
    else
        log_ok "No NOPASSWD sudo rules detected."
    fi
}
