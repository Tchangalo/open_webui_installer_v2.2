# no shebang — meant to be sourced
if [[ "${_MODULE_PORTAINER_LOADED:-}" == "1" ]]; then
  return
fi
_MODULE_PORTAINER_LOADED=1

# --- Portainer ---
apply_portainer_fix() {
  # Create systemd override to set DOCKER_MIN_API_VERSION for compatibility
  info "Applying Portainer compatibility fix."
  ${SUDO} mkdir -p "${OVERRIDE_DIR}"
  TMP="$(mktemp)"
  cat > "${TMP}" <<'EOF'
[Service]
Environment=DOCKER_MIN_API_VERSION=1.24
EOF
  ${SUDO} mv "${TMP}" "${OVERRIDE_FILE}"
  ${SUDO} chmod 644 "${OVERRIDE_FILE}"
  ${SUDO} systemctl daemon-reload
  ${SUDO} systemctl restart docker
  succ "Portainer compatibility fix applied."
}

install_portainer() {
  # Create volume and run Portainer container
  ${SUDO} docker volume create "${PORTAINER_VOLUME}" >/dev/null
  if ${SUDO} docker ps -a --format '{{.Names}}' | grep -x "${PORTAINER_NAME}" >/dev/null 2>&1; then
    warn "Existing Portainer container found — removing."
    ${SUDO} docker rm -f "${PORTAINER_NAME}" || true
  fi
  # Remove portainer volume if exists. COMMENT THIS OUT IF YOU WANT TO KEEP YOUR DATA
  if ${SUDO} docker volume ls --format '{{.Name}}' | grep -x "${PORTAINER_VOLUME}" >/dev/null 2>&1; then
    ${SUDO} docker volume rm "${PORTAINER_VOLUME}" || true
    succ "Portainer volume '${PORTAINER_VOLUME}' removed."
  fi
  info "Deploying Portainer container."
  ${SUDO} docker run -d \
    -p ${PORTAINER_PORT_EDGE}:8000 -p ${PORTAINER_PORT_HTTP}:9000 \
    --name "${PORTAINER_NAME}" \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${PORTAINER_VOLUME}:/data" \
    "${PORTAINER_IMAGE}"
  succ "Portainer deployed on ports ${PORTAINER_PORT_HTTP} and ${PORTAINER_PORT_EDGE}."
}

remove_portainer_if_installed() {
  # Remove Portainer container and its volume 
  if ${SUDO} docker ps -a --format '{{.Names}}' | grep -x "${PORTAINER_NAME}" >/dev/null 2>&1; then
    warn "Removing existing Portainer container."
    ${SUDO} docker rm -f "${PORTAINER_NAME}" || true
  else
    info "No Portainer container present."
  fi
  # Remove portainer volume if exists. COMMENT THIS OUT IF YOU WANT TO KEEP YOUR DATA
  if ${SUDO} docker volume ls --format '{{.Name}}' | grep -x "${PORTAINER_VOLUME}" >/dev/null 2>&1; then
    ${SUDO} docker volume rm "${PORTAINER_VOLUME}" || true
    succ "Portainer volume '${PORTAINER_VOLUME}' removed."
  fi
}
