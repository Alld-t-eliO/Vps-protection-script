ssh_configuration() {
    section "SSH CONFIGURATION"

    ssh_config=$(sshd -T 2>/dev/null)

    root_login=$(
        echo "$ssh_config" \
        | awk '$1 == "permitrootlogin" {print $2}'
    )

    password_auth=$(
        echo "$ssh_config" \
        | awk '$1 == "passwordauthentication" {print $2}'
    )

    log "PermitRootLogin: $root_login"
    log "PasswordAuthentication: $password_auth"

    if [ -z "$root_login" ]; then
        log "[ERROR] Unable to determine PermitRootLogin"
    elif [ "$root_login" = "no" ]; then
        log "[OK] Root login is disabled"
    else
        log "[CRITICAL] Root SSH login is not fully disabled: $root_login"
    fi

    if [ -z "$password_auth" ]; then
        log "[ERROR] Unable to determine PasswordAuthentication"
    elif [ "$password_auth" = "no" ]; then
        log "[OK] Password authentication is disabled"
    else
        log "[CRITICAL] SSH password authentication is enabled"
    fi
}


ssh_fail2ban() {
    section "FAIL2BAN SSH"

    if ! command -v fail2ban-client >/dev/null 2>&1; then
        log "[INFO] Fail2Ban is not installed"
        return
    fi

    if ! systemctl is-active --quiet fail2ban; then
        log "[WARNING] Fail2Ban is not running"
        return
    fi

    fail2ban-client status sshd \
    | tee -a "$REPORT"
}


ssh_current_connections() {
    section "CURRENT SSH CONNECTIONS"

    connections=$(
        ss -tnp 2>/dev/null \
        | grep ssh || true
    )

    if [ -z "$connections" ]; then
        log "No current SSH connections detected."
        return
    fi

    echo "$connections" \
    | tee -a "$REPORT"
}