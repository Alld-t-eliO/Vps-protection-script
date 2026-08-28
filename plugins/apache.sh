check_apache() {
    section "PLUGIN: APACHE"

    apache_bin=""
    command -v apache2 >/dev/null 2>&1 && apache_bin="apache2"
    command -v httpd >/dev/null 2>&1 && apache_bin="httpd"

    if [ -z "$apache_bin" ]; then
        log_info "Apache is not installed."
        return
    fi

    "$apache_bin" -S 2>&1 | append_output

    if "$apache_bin" -M 2>/dev/null | grep -qi ssl; then
        log_ok "Apache SSL module appears enabled."
    else
        log_warning "Apache SSL module does not appear enabled." "Enable TLS for public sites or terminate TLS at a trusted reverse proxy."
    fi
}
