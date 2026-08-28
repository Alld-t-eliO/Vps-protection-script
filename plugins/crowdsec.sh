check_crowdsec() {
    section "PLUGIN: CROWDSEC"

    if ! command -v cscli >/dev/null 2>&1; then
        log_info "CrowdSec is not installed."
        return
    fi

    cscli metrics 2>/dev/null | append_output
    cscli decisions list 2>/dev/null | append_output
}
