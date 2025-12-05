# no shebang — this file is meant to be sourced
# Module guard
if [[ "${_MODULE_BOOTSTRAP_LOADED:-}" == "1" ]]; then
  return
fi
_MODULE_BOOTSTRAP_LOADED=1

# --- Color definitions ---
B='\033[0;94m'   # blue (info)
G='\033[0;32m'   # green (success)
Y='\e[33m'       # yellow (warning)
R='\033[91m'     # red (error)
NC='\033[0m'     # reset

# --- Configurable defaults ---
CHANNEL="${CHANNEL:-stable}"
COMPOSE_DEST="${COMPOSE_DEST:-/usr/local/bin/docker-compose}"
COMPOSE_TMP="${COMPOSE_TMP:-/tmp/docker-compose.$$}"
OVERRIDE_DIR="${OVERRIDE_DIR:-/etc/systemd/system/docker.service.d}"
OVERRIDE_FILE="${OVERRIDE_FILE:-${OVERRIDE_DIR}/override.conf}"
PORTAINER_VOLUME="${PORTAINER_VOLUME:-portainer_data}"
PORTAINER_NAME="${PORTAINER_NAME:-portainer}"
PORTAINER_IMAGE="${PORTAINER_IMAGE:-portainer/portainer-ce}"
PORTAINER_PORT_HTTP="${PORTAINER_PORT_HTTP:-9000}"
PORTAINER_PORT_EDGE="${PORTAINER_PORT_EDGE:-8000}"

# --- Determine sudo usage ---
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    printf '%b\n' "${R}ERROR: not running as root and sudo not available.${NC}" >&2
    exit 1
  fi
fi

# --- Logging helpers ---
info() { printf '%b\n' "${B}$*${NC}"; }
succ() { printf '%b\n' "${G}$*${NC}"; }
warn() { printf '%b\n' "${Y}$*${NC}"; }
err()  { printf '%b\n' "${R}ERROR: $*${NC}" >&2; }

# --- Status display ---

# ------------------------
# Status display at start (text log)
# ------------------------
show_current_status() {
  # Show which modules are present and which containers are running.
  # This function prints a short summary before prompting the user.
  info "=== Current system status ==="

  # Docker presence
  if command -v docker >/dev/null 2>&1; then
    succ "Docker: installed"
    DOCKER_PRESENT=1
  else
    info "Docker: not installed"
    DOCKER_PRESENT=0
  fi

  # Docker Compose presence
  if [ -x "${COMPOSE_DEST}" ] || command -v docker-compose >/dev/null 2>&1; then
    succ "Docker Compose: installed"
    COMPOSE_PRESENT=1
  else
    info "Docker Compose: not installed"
    COMPOSE_PRESENT=0
  fi

  # Portainer container presence / running
  if command -v docker >/dev/null 2>&1; then
    if ${SUDO} docker ps -a --format '{{.Names}}' 2>/dev/null | grep -x "${PORTAINER_NAME}" >/dev/null 2>&1; then
      if ${SUDO} docker ps --format '{{.Names}}' 2>/dev/null | grep -x "${PORTAINER_NAME}" >/dev/null 2>&1; then
        succ "Portainer: container present and running (name='${PORTAINER_NAME}')"
        PORTAINER_PRESENT=1
        PORTAINER_RUNNING=1
      else
        warn "Portainer: container present but not running (name='${PORTAINER_NAME}')"
        PORTAINER_PRESENT=1
        PORTAINER_RUNNING=0
      fi
    else
      info "Portainer: no container present"
      PORTAINER_PRESENT=0
      PORTAINER_RUNNING=0
    fi
  else
    info "Portainer: docker not available — cannot check containers"
    PORTAINER_PRESENT=0
    PORTAINER_RUNNING=0
  fi

  # Open-WebUI container presence / running
  if command -v docker >/dev/null 2>&1; then
    if ${SUDO} docker ps -a --format '{{.Names}}' 2>/dev/null | grep -x "open-webui" >/dev/null 2>&1; then
      if ${SUDO} docker ps --format '{{.Names}}' 2>/dev/null | grep -x "open-webui" >/dev/null 2>&1; then
        succ "Open-WebUI: container present and running (name='open-webui')"
        WEBUI_PRESENT=1
        WEBUI_RUNNING=1
      else
        warn "Open-WebUI: container present but not running (name='open-webui')"
        WEBUI_PRESENT=1
        WEBUI_RUNNING=0
      fi
    else
      info "Open-WebUI: no container present"
      WEBUI_PRESENT=0
      WEBUI_RUNNING=0
    fi
  else
    info "Open-WebUI: docker not available — cannot check containers"
    WEBUI_PRESENT=0
    WEBUI_RUNNING=0
  fi

  info "============================="
}

# ------------------------
# Status display at end
# ------------------------
show_final_status() {
    STATUS_TMPFILE="$(mktemp /tmp/status.XXXXXX)"
    STATUS_MSG="=== Final system status ===\n\n"

    # Docker
    if command -v docker >/dev/null 2>&1; then
        STATUS_MSG+="✔ Docker: installed\n"
    else
        STATUS_MSG+="• Docker: not installed\n"
    fi

    # Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        STATUS_MSG+="✔ Docker Compose: installed\n"
    else
        STATUS_MSG+="• Docker Compose: not installed\n"
    fi

    # Portainer
    PORT_NAME="${PORTAINER_NAME:-portainer}"
    if command -v docker >/dev/null 2>&1; then
        if docker ps -a --format '{{.Names}}' | grep -x "$PORT_NAME" >/dev/null 2>&1; then
            if docker ps --format '{{.Names}}' | grep -x "$PORT_NAME" >/dev/null 2>&1; then
                STATUS_MSG+="✔ Portainer: container running\n"
            else
                STATUS_MSG+="⚠ Portainer: container present but stopped\n"
            fi
        else
            STATUS_MSG+="• Portainer: no container\n"
        fi
    else
        STATUS_MSG+="• Portainer: docker unavailable\n"
    fi

    # Open-WebUI
    WEBUI_NAME="${WEBUI_NAME:-open-webui}"
    if command -v docker >/dev/null 2>&1; then
        if docker ps -a --format '{{.Names}}' | grep -x "$WEBUI_NAME" >/dev/null 2>&1; then
            if docker ps --format '{{.Names}}' | grep -x "$WEBUI_NAME" >/dev/null 2>&1; then
                STATUS_MSG+="✔ Open-WebUI: container running\n"
            else
                STATUS_MSG+="⚠ Open-WebUI: container present but stopped\n"
            fi
        else
            STATUS_MSG+="• Open-WebUI: no container\n"
        fi
    else
        STATUS_MSG+="• Open-WebUI: docker unavailable\n"
    fi

    STATUS_MSG+="\nTime: $(date '+%Y-%m-%d %H:%M:%S')\n"
    STATUS_MSG+="=============================\n"

    printf "%b" "$STATUS_MSG" > "$STATUS_TMPFILE"
    
    # Create dialog window
    dialog --exit-label "OK" --title "System Status" --textbox "$STATUS_TMPFILE" 0 40
    rm -f "$STATUS_TMPFILE"
}

# --- Prompt helpers ---
prompt_yes_no() {
  local resp
  while true; do
    read -r -p "$1 [y/N]: " resp
    case "${resp,,}" in
      y|yes) return 0 ;;
      n|no|"") return 1 ;;
      *) printf '%b\n' "${Y}Please enter '\''y'\'' or '\''n'\'.${NC}" ;;
    esac
  done
}

prompt_action() {
  local resp
  while true; do
    read -r -p "Do you want to (i)nstall or (r)emove modules? [i/r]: " resp
    case "${resp,,}" in
      i|install) echo "install"; return 0 ;;
      r|remove|uninstall|deinstall) echo "remove"; return 0 ;;
      *)
        printf '%b\n' "${Y}Please enter 'i' (install) or 'r' (remove).${NC}"
        ;;
    esac
  done
}
