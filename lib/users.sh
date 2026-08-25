check_users() {
    section "USERS"

    log "Users with a valid shell:"

    getent passwd \
    | awk -F: '$7 !~ /(nologin|false)$/ {
        print " - " $1 " | UID=" $3 " | shell=" $7
    }' \
    | tee -a "$REPORT"

    root_users=$(awk -F: '$3 == 0 {print $1}' /etc/passwd)
    root_count=$(echo "$root_users" | wc -l)

    if [ "$root_count" -eq 1 ]; then
        log "[OK] Only one UID 0 account exists"
    else
        log "[CRITICAL] Multiple UID 0 accounts detected: $root_users"
    fi
}