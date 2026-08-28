check_backups() {
    section "PLUGIN: BACKUPS"

    backup_paths="/backup /backups /var/backups /srv/backups"
    found=0

    for backup_path in $backup_paths; do
        [ -d "$backup_path" ] || continue
        found=1
        log_info "Backup path exists: $backup_path"
        find "$backup_path" -maxdepth 2 -type f -mtime -7 2>/dev/null | head -n 50 | append_output
    done

    [ "$found" -eq 0 ] && log_warning "No common backup directory found." "Configure regular off-host backups and document restore steps."
}
