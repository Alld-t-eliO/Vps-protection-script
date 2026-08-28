check_certificates() {
    section "PLUGIN: TLS CERTIFICATES"

    cert_dirs="/etc/letsencrypt/live /etc/ssl/certs"
    found=0

    for cert_dir in $cert_dirs; do
        [ -d "$cert_dir" ] || continue
        certs=$(find "$cert_dir" -type f \( -name "fullchain.pem" -o -name "*.crt" \) 2>/dev/null | head -n 50)

        [ -n "$certs" ] && found=1

        while read -r cert; do
            [ -z "$cert" ] && continue
            found=1
            expiry=$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2- || true)
            [ -n "$expiry" ] && log_info "$cert expires: $expiry"
        done <<< "$certs"
    done

    [ "$found" -eq 0 ] && log_info "No common TLS certificate files found."
}
