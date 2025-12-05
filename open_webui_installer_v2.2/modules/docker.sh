# no shebang — this file is meant to be sourced
# Module guard
if [[ "${_MODULE_DOCKER_LOADED:-}" == "1" ]]; then
  return
fi
_MODULE_DOCKER_LOADED=1

# --- Docker ---
remove_docker_if_installed() {
  # Remove docker-related packages, data and files if present
  if command -v docker >/dev/null 2>&1 || dpkg -l 2>/dev/null | grep -E 'docker|containerd' >/dev/null 2>&1; then
    warn "Existing Docker installation detected — removing."
    ${SUDO} apt-get update -y
    ${SUDO} apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
    ${SUDO} apt-get autoremove -y || true
    ${SUDO} rm -rf /var/lib/docker /var/lib/containerd || true
    ${SUDO} rm -f /usr/local/bin/docker-compose /usr/bin/docker-compose || true
    # Also remove leftover docker systemd override if present
    ${SUDO} rm -f "${OVERRIDE_FILE}" || true
    ${SUDO} systemctl daemon-reload || true
    succ "Docker removal completed."
  else
    info "No Docker installation found."
  fi
}

install_docker() {
  # Install Docker using the official convenience script
  info "Installing Docker (channel=${CHANNEL})."
  if ! command -v curl >/dev/null 2>&1; then
    warn "curl missing — installing."
    ${SUDO} apt-get update -y
    ${SUDO} apt-get install -y curl ca-certificates gnupg lsb-release
  fi
  ${SUDO} bash -c "CHANNEL=${CHANNEL} && curl -fsSL https://get.docker.com | sh"
  ${SUDO} systemctl enable --now docker
  succ "Docker successfully installed."
}

add_user_to_docker_group() {
  # Add the invoking user (when using sudo) or $USER to docker group
  TARGET_USER="${SUDO:+${SUDO_USER:-$USER}}"
  if [ -n "${TARGET_USER}" ]; then
    if getent group docker >/dev/null 2>&1; then
      ${SUDO} usermod -aG docker "${TARGET_USER}" || err "user modification failed"
      succ "User '${TARGET_USER}' added to docker group."
    fi
  fi
}

# --- Docker helper functions (for other modules) ---
docker_container_exists() {
  # $1 = container name
  local name="$1"
  ${SUDO} docker ps -a --format '{{.Names}}' | grep -x -- "$name" >/dev/null 2>&1
}

docker_start_container() {
  # $1 = container name
  local name="$1"
  if ! command -v docker >/dev/null 2>&1; then
    err "docker not installed" >&2
    return 1
  fi
  if docker_container_exists "$name"; then
    ${SUDO} docker start "$name"
  else
    err "container '$name' does not exist" >&2
    return 2
  fi
}

docker_stop_container() {
  # $1 = container name
  local name="$1"
  ${SUDO} docker stop "$name" >/dev/null 2>&1 || return $?
}
