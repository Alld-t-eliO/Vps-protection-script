ssh_configuration() {
    subsection "SSH CONFIGURATION"

    if [ -n "${SSHD_T_FIXTURE:-}" ]; then
        ssh_config=$(cat "$SSHD_T_FIXTURE")
    else
        ssh_config=$(sshd -T 2>/dev/null)
    fi

    if [ -z "$ssh_config" ]; then
        log_error "Unable to read effective sshd configuration." "Run this scanner with sudo and confirm openssh-server is installed."
        return
    fi

    root_login=$(
        echo "$ssh_config" \
        | awk '$1 == "permitrootlogin" {print $2}'
    )

    password_auth=$(
        echo "$ssh_config" \
        | awk '$1 == "passwordauthentication" {print $2}'
    )
    permit_empty_passwords=$(
        echo "$ssh_config" \
        | awk '$1 == "permitemptypasswords" {print $2}'
    )
    max_auth_tries=$(
        echo "$ssh_config" \
        | awk '$1 == "maxauthtries" {print $2}'
    )
    ssh_port=$(
        echo "$ssh_config" \
        | awk '$1 == "port" {print $2}' \
        | paste -sd ',' -
    )

    log "PermitRootLogin: $root_login"
    log "PasswordAuthentication: $password_auth"
    log "PermitEmptyPasswords: $permit_empty_passwords"
    log "MaxAuthTries: $max_auth_tries"
    log "Port: $ssh_port"

    if [ -z "$root_login" ]; then
        log_error "Unable to determine PermitRootLogin." "Inspect /etc/ssh/sshd_config and sshd -T output."
    elif [ "$root_login" = "no" ]; then
        log_ok "Root login is disabled."
    else
        emit_level "${ROOT_SSH_SEVERITY:-CRITICAL}" "Root SSH login is not fully disabled: $root_login" "Set PermitRootLogin no in sshd_config, validate SSH access, then reload sshd."
    fi

    if [ -z "$password_auth" ]; then
        log_error "Unable to determine PasswordAuthentication." "Inspect /etc/ssh/sshd_config and sshd -T output."
    elif [ "$password_auth" = "no" ]; then
        log_ok "Password authentication is disabled."
    else
        emit_level "${SSH_PASSWORD_SEVERITY:-CRITICAL}" "SSH password authentication is enabled." "Use SSH keys, set PasswordAuthentication no, validate access, then reload sshd."
    fi

    if [ "$permit_empty_passwords" = "yes" ]; then
        log_critical "SSH permits empty passwords." "Set PermitEmptyPasswords no and reload sshd."
    else
        log_ok "SSH empty passwords are disabled."
    fi

    if [ -n "$max_auth_tries" ] && [ "$max_auth_tries" -gt 6 ] 2>/dev/null; then
        log_warning "SSH MaxAuthTries is high: $max_auth_tries" "Set MaxAuthTries 3 or 4 for exposed servers."
    fi
}


ssh_fail2ban() {
    subsection "FAIL2BAN SSH"

    if ! command -v fail2ban-client >/dev/null 2>&1; then
        emit_level "${FAIL2BAN_MISSING_SEVERITY:-WARNING}" "Fail2Ban is not installed." "Install and configure fail2ban for internet-exposed SSH servers."
        return
    fi

    if ! systemctl is-active --quiet fail2ban; then
        emit_level "${FAIL2BAN_MISSING_SEVERITY:-WARNING}" "Fail2Ban is not running." "Start and enable fail2ban with systemctl enable --now fail2ban."
        return
    fi

    fail2ban-client status sshd \
    | append_output

    fail2ban-client status 2>/dev/null | append_output
}


ssh_authorized_keys_diff() {
    subsection "SSH AUTHORIZED_KEYS BASELINE"

    snapshot="$SCAN_DIR/authorized_keys.snapshot"
    baseline_snapshot="$BASELINE_ROOT/authorized_keys.snapshot"
    baseline_hash="$BASELINE_ROOT/authorized_keys.snapshot.sha256"

    find /root /home -path "*/.ssh/authorized_keys" -type f -print 2>/dev/null \
    | while read -r file; do
        echo "### $file"
        cat "$file" 2>/dev/null
    done > "$snapshot"

    if [ ! -s "$snapshot" ]; then
        log_info "No authorized_keys files found."
        return
    fi

    current_hash=$(hash_file "$snapshot")
    log_info "authorized_keys combined hash: $current_hash"

    if [ "$SAVE_BASELINE" -eq 1 ]; then
        mkdir -p "$BASELINE_ROOT"
        cp "$snapshot" "$baseline_snapshot"
        hash_file "$baseline_snapshot" > "$baseline_hash"
        log_ok "authorized_keys baseline saved."
        return
    fi

    if [ -f "$baseline_snapshot" ] && [ -f "$baseline_hash" ]; then
        expected_hash=$(cat "$baseline_hash")
        if [ "$expected_hash" != "$current_hash" ]; then
            log_warning "authorized_keys changed since baseline." "Review added or removed SSH keys before accepting the new baseline."
            diff -u "$baseline_snapshot" "$snapshot" 2>/dev/null | append_output || true
        else
            log_ok "authorized_keys match the saved baseline."
        fi
    else
        log_info "No authorized_keys baseline found."
    fi
}


ssh_current_connections() {
    subsection "CURRENT SSH CONNECTIONS"

    connections=$(
        ss -tnp 2>/dev/null \
        | grep ssh || true
    )

    if [ -z "$connections" ]; then
        log_info "No current SSH connections detected."
        return
    fi

    echo "$connections" \
    | append_output
}


ssh_successful_connections() {
    subsection "SUCCESSFUL SSH CONNECTIONS"

    journalctl -u ssh --no-pager -q 2>/dev/null \
    | grep "Accepted" \
    | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
    | sort \
    | uniq -c \
    | sort -nr \
    | append_output
}


ssh_failed_attempts() {
    subsection "FAILED SSH ATTEMPTS - LAST 24H"

    journalctl -u ssh --since "24 hours ago" --no-pager -q 2>/dev/null \
    | grep -E "Failed password|Invalid user|authentication failure" \
    | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
    | sort \
    | uniq -c \
    | sort -nr \
    | append_output
}


check_ssh() {
    section "SSH"

    ssh_configuration
    ssh_fail2ban
    ssh_authorized_keys_diff
}


check_ssh_activity() {
    section "SSH ACTIVITY"

    ssh_successful_connections
    ssh_failed_attempts
    ssh_current_connections
}
