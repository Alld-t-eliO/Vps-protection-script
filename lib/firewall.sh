firewall_status() {
    section "FIREWALL STATUS"

    if ! command -v ufw >/dev/null 2>&1; then
        log "[CRITIC] UFW no installed."
        return
    fi 

    if ! ufw status | grep -q "Status: active"; then
        log "[CRITIC] UFW not activated"
        return
    fi

    log "[OK] UFW firewall is active."

    ufw status verbose \
    | tee -a "$REPORT"
}


firewall_rules() {
    section "FIREWALL RULES"

    ufw status numbered \
    | tee -a "$REPORT"
}
