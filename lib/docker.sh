docker_status() {
    section "STATUS DOCKER"

    if ! command -v docker >/dev/null 2>&1; then
        log "[INFO] Docker is not installed."
        return
    fi

    if systemctl is-active --quiet docker; then
        log "[OK] Docker is active"
    else 
        log "[WARNING]Docker is inactive."

    systemctl is-active docker \
    | tee -a "$REPORT"
}

docker_containers() {

}


docker_exposed_ports() {

}


docker_privileged_containers() {

}