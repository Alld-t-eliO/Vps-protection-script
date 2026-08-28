check_nginx() {
    section "PLUGIN: NGINX"

    if ! command -v nginx >/dev/null 2>&1; then
        log_info "Nginx is not installed."
        return
    fi

    nginx -T 2>/dev/null | grep -Ei "listen|ssl_certificate|ssl_protocols|server_tokens" | append_output

    if nginx -T 2>/dev/null | grep -qi "server_tokens on"; then
        log_warning "Nginx server_tokens appears enabled." "Set server_tokens off; in the nginx http block."
    else
        log_ok "Nginx server_tokens is not explicitly enabled."
    fi
}
