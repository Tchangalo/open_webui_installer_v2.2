#!/usr/bin/env bash
set -euo pipefail

# --- Import system ---
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$DIR/modules"

import() {
  for mod in "$@"; do
    file="$MODULE_DIR/${mod}.sh"
    if [[ ! -f "$file" ]]; then
      printf 'ERROR: module not found: %s\n' "$file" >&2
      exit 1
    fi
    source "$file"
  done
}

# Import modules explicitly (order controlled here)
import 00-bootstrap docker docker_compose portainer open_webui

main() {
  # Show current status before prompting the user
  show_current_status

  info "=== Select action and modules ==="

  ACTION="$(prompt_action)"
  # Initialize selections as empty
  DOCKER_SEL=""
  COMPOSE_SEL=""
  PORTAINER_SEL=""
  WEBUI_SEL=""

  if [ "${ACTION}" = "install" ]; then
    if prompt_yes_no "Install Docker?"; then DOCKER_SEL="yes"; else DOCKER_SEL="no"; fi
    if prompt_yes_no "Install Docker Compose?"; then COMPOSE_SEL="yes"; else COMPOSE_SEL="no"; fi
    if prompt_yes_no "Install Portainer?"; then PORTAINER_SEL="yes"; else PORTAINER_SEL="no"; fi
    if prompt_yes_no "Install Open-WebUI?"; then WEBUI_SEL="yes"; else WEBUI_SEL="no"; fi
  else
    if prompt_yes_no "Remove Docker (and associated data)?"; then DOCKER_SEL="yes"; else DOCKER_SEL="no"; fi
    if prompt_yes_no "Remove Docker Compose?"; then COMPOSE_SEL="yes"; else COMPOSE_SEL="no"; fi
    if prompt_yes_no "Remove Portainer (container + volume)?"; then PORTAINER_SEL="yes"; else PORTAINER_SEL="no"; fi
    if prompt_yes_no "Remove Open-WebUI (container + volumes)?"; then WEBUI_SEL="yes"; else WEBUI_SEL="no"; fi
  fi

  ACTIONS_PERFORMED=0
  INSTALL_COUNT=0
  CONTAINERS_STARTED=0
  WEBUI_INSTALLED=0

  # Docker
  if [[ "${DOCKER_SEL}" == "yes" && "${ACTION}" == "install" ]]; then
    info "==> Docker: starting installation"
    remove_docker_if_installed
    install_docker
    add_user_to_docker_group
    ACTIONS_PERFORMED=$((ACTIONS_PERFORMED+1))
    INSTALL_COUNT=$((INSTALL_COUNT+1))
  elif [[ "${DOCKER_SEL}" == "yes" && "${ACTION}" == "remove" ]]; then
    info "==> Docker: starting removal"
    remove_docker_if_installed
    ACTIONS_PERFORMED=$((ACTIONS_PERFORMED+1))
  fi

  # Docker Compose
  if [[ "${COMPOSE_SEL}" == "yes" && "${ACTION}" == "install" ]]; then
    info "==> Docker Compose: starting installation"
    remove_docker_compose_if_installed
    install_docker_compose
    ACTIONS_PERFORMED=$((ACTIONS_PERFORMED+1))
    INSTALL_COUNT=$((INSTALL_COUNT+1))
  elif [[ "${COMPOSE_SEL}" == "yes" && "${ACTION}" == "remove" ]]; then
    info "==> Docker Compose: starting removal"
    remove_docker_compose_if_installed
    ACTIONS_PERFORMED=$((ACTIONS_PERFORMED+1))
  fi

  # Portainer
  if [[ "${PORTAINER_SEL}" == "yes" && "${ACTION}" == "install" ]]; then
    info "==> Portainer: starting installation"
    apply_portainer_fix
    install_portainer
    ACTIONS_PERFORMED=$((ACTIONS_PERFORMED+1))
    INSTALL_COUNT=$((INSTALL_COUNT+1))
  elif [[ "${PORTAINER_SEL}" == "yes" && "${ACTION}" == "remove" ]]; then
    info "==> Portainer: starting removal"
    remove_portainer_if_installed
    ACTIONS_PERFORMED=$((ACTIONS_PERFORMED+1))
  fi

  # Open-WebUI
  if [[ "${WEBUI_SEL}" == "yes" && "${ACTION}" == "install" ]]; then
    info "==> Open-WebUI: starting installation"
    install_webui
    ACTIONS_PERFORMED=$((ACTIONS_PERFORMED+1))
    INSTALL_COUNT=$((INSTALL_COUNT+1))
    WEBUI_INSTALLED=$((WEBUI_INSTALLED+1))
  elif [[ "${WEBUI_SEL}" == "yes" && "${ACTION}" == "remove" ]]; then
    info "==> Open-WebUI: starting removal"
    remove_webui_if_installed
    ACTIONS_PERFORMED=$((ACTIONS_PERFORMED+1))
  fi

  if [ "${ACTIONS_PERFORMED}" -gt 0 ]; then
      succ "=== Selected actions completed (${ACTIONS_PERFORMED} tasks executed) ==="
  fi

  show_final_status

  # --- Reboot only if Open WebUI was newly set up ---
  if [ "${WEBUI_INSTALLED}" -eq 1 ]; then
      info "Open WebUI was (re-)set up — rebooting..."
      ${SUDO:-} reboot
  else
      info "Open WebUI not set up this run — reboot skipped."
  fi

}

main "$@"
