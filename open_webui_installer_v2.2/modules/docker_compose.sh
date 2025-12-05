# no shebang — meant to be sourced
if [[ "${_MODULE_DOCKER_COMPOSE_LOADED:-}" == "1" ]]; then
  return
fi
_MODULE_DOCKER_COMPOSE_LOADED=1

# --- Docker Compose ---
remove_docker_compose_if_installed() {
  # Remove docker-compose binary if present
  if [ -x "${COMPOSE_DEST}" ] || command -v docker-compose >/dev/null 2>&1; then
    warn "Existing docker-compose installation detected — removing."
    ${SUDO} rm -f "${COMPOSE_DEST}" || true
    ${SUDO} rm -f /usr/bin/docker-compose || true
    succ "docker-compose removed."
  else
    info "No docker-compose installation found."
  fi
}

install_docker_compose() {
  # Download and install latest docker-compose release from GitHub
  info "Installing docker-compose."
  LATEST_URL="$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/docker/compose/releases/latest)"
  LATEST_TAG="${LATEST_URL##*/}"
  DOWNLOAD_URL="https://github.com/docker/compose/releases/download/${LATEST_TAG}/docker-compose-$(uname -s)-$(uname -m)"
  curl -fSL "${DOWNLOAD_URL}" -o "${COMPOSE_TMP}"
  ${SUDO} mv "${COMPOSE_TMP}" "${COMPOSE_DEST}"
  ${SUDO} chmod +x "${COMPOSE_DEST}"
  if ${SUDO} "${COMPOSE_DEST}" version >/dev/null 2>&1; then
    succ "docker-compose installation successful."
  else
    err "docker-compose installation failed."
    exit 1
  fi
}
