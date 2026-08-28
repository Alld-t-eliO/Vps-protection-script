filesystem_world_writable() {
    subsection "WORLD-WRITABLE FILES"

    files=$(
        find / -xdev -type f -perm -0002 2>/dev/null
    )

    if [ -z "$files" ]; then
        log_ok "No world-writable files detected."
        return
    fi

    count=$(echo "$files" | wc -l)

    log_warning "$count world-writable file(s) detected." "Review ownership and remove world-write permissions where unnecessary."

    echo "$files" \
    | append_output
}


filesystem_suid_sgid() {
    subsection "SUID / SGID FILES"

    files=$(
        find / -xdev -type f \
        \( -perm -4000 -o -perm -2000 \) \
        2>/dev/null
    )

    if [ -z "$files" ]; then
        log_ok "No SUID/SGID files detected."
        return
    fi

    log_info "SUID/SGID files detected for review:"

    echo "$files" \
    | append_output
}


filesystem_sensitive_permissions() {
    subsection "SENSITIVE FILE PERMISSIONS"

    files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/group"
        "/etc/gshadow"
        "/etc/ssh/sshd_config"
    )

    for file in "${files[@]}"; do

        if [ ! -e "$file" ]; then
            log_warning "$file does not exist."
            continue
        fi

        permissions=$(stat -c "%a" "$file")
        owner=$(stat -c "%U:%G" "$file")

        log "$file -> permissions=$permissions owner=$owner"
    done
}


filesystem_tmp_mount_options() {
    subsection "TMP MOUNT OPTIONS"

    for mountpoint in /tmp /var/tmp /dev/shm; do
        if findmnt "$mountpoint" >/dev/null 2>&1; then
            options=$(findmnt -no OPTIONS "$mountpoint" 2>/dev/null || true)
            log "$mountpoint -> $options"

            echo "$options" | grep -qw noexec || log_warning "$mountpoint is missing noexec." "Consider adding noexec for $mountpoint if application compatibility allows it."
            echo "$options" | grep -qw nosuid || log_warning "$mountpoint is missing nosuid." "Consider adding nosuid for $mountpoint."
            echo "$options" | grep -qw nodev || log_warning "$mountpoint is missing nodev." "Consider adding nodev for $mountpoint."
        else
            log_info "$mountpoint is not a separate mount."
        fi
    done
}


check_filesystem() {
    section "FILESYSTEM / PERMISSIONS"

    filesystem_world_writable
    filesystem_suid_sgid
    filesystem_sensitive_permissions
    filesystem_tmp_mount_options
}
