# no shebang — meant to be sourced
if [[ "${_MODULE_OPEN_WEBUI_LOADED:-}" == "1" ]]; then
  return
fi
_MODULE_OPEN_WEBUI_LOADED=1

# --- Open-WebUI ---
install_webui() {
  # Deploy Open-WebUI container (ollama-backed)
  info "Starting Open-WebUI installation."
  if ${SUDO} docker ps -a --format '{{.Names}}' | grep -x "open-webui" >/dev/null 2>&1; then
    warn "Existing open-webui container found — removing."
    ${SUDO} docker rm -f open-webui || true
  fi
  info "Creating volumes (ollama, open-webui)."
  ${SUDO} docker volume create ollama >/dev/null || true
  ${SUDO} docker volume create open-webui >/dev/null || true
  info "Deploying Open-WebUI container."
  ${SUDO} docker run -d \
    -p 3000:8080 \
    -v ollama:/root/.ollama \
    -v open-webui:/app/backend/data \
    --name open-webui \
    --restart always \
    ghcr.io/open-webui/open-webui:ollama
  succ "Open-WebUI running on port 3000."
}

remove_webui_if_installed() {
  # Remove open-webui container and its volumes
  if ${SUDO} docker ps -a --format '{{.Names}}' | grep -x "open-webui" >/dev/null 2>&1; then
    warn "Removing existing open-webui container."
    ${SUDO} docker rm -f open-webui || true
  else
    info "No open-webui container present."
  fi
  # Remove volumes if present
  if ${SUDO} docker volume ls --format '{{.Name}}' | grep -x "ollama" >/dev/null 2>&1; then
    ${SUDO} docker volume rm ollama || true
    succ "Volume 'ollama' removed."
  fi
  if ${SUDO} docker volume ls --format '{{.Name}}' | grep -x "open-webui" >/dev/null 2>&1; then
    ${SUDO} docker volume rm open-webui || true
    succ "Volume 'open-webui' removed."
  fi
}
