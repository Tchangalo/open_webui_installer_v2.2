This script essentially executes the following commands:

## Uninstall Docker

Remove existing Docker installation, if present:

```bash
sudo apt-get update -y
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
sudo apt-get autoremove -y || true
sudo rm -rf /var/lib/docker /var/lib/containerd || true
sudo rm -f /usr/local/bin/docker-compose /usr/bin/docker-compose || true
```

## Install Docker

Install dependencies:

```bash
sudo apt-get update -y
sudo apt-get install -y curl ca-certificates gnupg lsb-release
```

Install Docker via the official script:

```bash
CHANNEL=stable
sudo bash -c "CHANNEL=${CHANNEL} && curl -fsSL https://get.docker.com | sh"
```

Enable/start Docker:

```bash
sudo systemctl enable --now docker
```

Add user to docker group:

```bash
sudo usermod -aG docker <username>
```

## Install Docker Compose

Remove existing docker-compose, if present:

```bash
sudo rm -f /usr/local/bin/docker-compose
```

Install docker-compose (latest release is fetched automatically).
Determine latest release URL and tag:

```bash
LATEST_URL="$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/docker/compose/releases/latest)"
LATEST_TAG="${LATEST_URL##*/}"
DOWNLOAD_URL="https://github.com/docker/compose/releases/download/${LATEST_TAG}/docker-compose-$(uname -s)-$(uname -m)"
```

Download into a temporary file (COMPOSE_TMP):

```bash
curl -fSL "${DOWNLOAD_URL}" -o /tmp/docker-compose.$$
```
Move file and make it executable:

```bash
sudo mv /tmp/docker-compose.$$ /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

Verify installation:

```
sudo /usr/local/bin/docker-compose version
```

## Fix for Portainer on Docker 29

Create override file:
```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
```

Create a temporary file and insert content:

```bash
TMP="$(mktemp)"
cat > "${TMP}" <<'EOF'
[Service]
Environment=DOCKER_MIN_API_VERSION=1.24
EOF
```

Move the override file, set permissions, reload systemd, and restart Docker:

```bash
sudo mv "${TMP}" /etc/systemd/system/docker.service.d/override.conf
sudo chmod 644 /etc/systemd/system/docker.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart docker
```

## Set up Portainer

Create Portainer volume:

```bash
sudo docker volume create portainer_data >/dev/null
```
Remove existing Portainer container, if present:

```bash
sudo docker rm -f portainer || true
```
Start Portainer container:

```bash
sudo docker run -d \
  -p 8000:8000 -p 9000:9000 \
  --name "portainer" \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "portainer_data:/data" \
  "portainer/portainer-ce"
```

## Set up Open WebUI

Remove existing open-webui container, if present:

```bash
sudo docker rm -f open-webui || true
```

Create required volumes:

```bash
sudo docker volume create ollama >/dev/null || true
sudo docker volume create open-webui >/dev/null || true
```

Start Open WebUI container:

```bash
sudo docker run -d \
  -p 3000:8080 \
  -v ollama:/root/.ollama \
  -v open-webui:/app/backend/data \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:ollama
```

Reboot:

```bash
sudo reboot
```

---

## Warning and Target Groups

Anyone who simply runs the script without understanding the process will not know what is happening. Therefore, the first installation should be done manually by entering the commands into the terminal one by one. This ensures you see exactly what happens. Once you are familiar with Open WebUI and no longer want to spend time on manual (re-)installations, the script becomes a useful helper.

Second, the script is for anyone who failed while performing a manual installation.

Third, it can be interesting to see how the commands listed above can be packaged into a Bash script.

---

## System Requirements

Tested on:

* Debian 13.2
* Ubuntu Server 24.0.3
* Mint 21.3, 22.1, 22.2

So it should also work on Ubuntu derivatives (Linux Lite, PopOS, etc.) and Debian derivatives (ParrotOS, Kali, etc.).

Especially Debian 13 requires the following adjustments:

1. Comment out the CD-ROM entry in `/etc/apt/sources.list`:

```text
#deb cdrom:[Debian GNU/Linux 13.1.0 _Trixie_ ...]/ trixie contrib main non-free-firmware
```

2. Log in as root and install sudo:

```bash
apt-get update
apt install -y sudo
```

3. Add user to sudo group:

```bash
usermod -aG sudo <username>
```

The script should run without changes on all Debian-based systems, I guess.

---

## Quickstart

1. Copy the _inner_ folder `open_webui_installer_v2.1` to the home directory of the user, e.g:

```
scp open_webui_installer_v2.1 <username>@<server-ip>:/home/<username>
```

2. Make all scripts in the folder executable:

```
sudo chmod -R +x setup_open_webui.sh
```

3. Change into the installer directory:

```bash
cd open_webui_installer_v2.1
```

4. Run the setup script:

```
./setup_open_webui.sh
```

Portainer is accessible in the browser at `<server-ip>:9000`, where an admin account must be created immediately.
Open WebUI is accessible at `<server-ip>:3000`. The first startup of the Open WebUI container may take several minutes. With any subsequent reboots or boots it should jump quickly to *healthy*.

### GPU Support

Add the following flag to the Docker run command in Open WebUI section:

```
--gpus all
```
Like this:
```bash
${SUDO} docker run -d \
    -p 3000:8080 \
    -v ollama:/root/.ollama \
    -v open-webui:/app/backend/data \
    --gpus all \
    --name open-webui \
    --restart always \
    ghcr.io/open-webui/open-webui:ollama
succ "Open-WebUI running on port 3000 with GPU support."
```
---

## New Features of open_webui_installer_v2.0

While _open\_webui_installer_v1.0_ simply installs/sets up the four modules Docker, Docker Compose, Portainer and Open WebUI one after another, _open\_webui_installer_v2.0_ prompts the user for the action to be executed and the modules:

1. Do you want to _install_ or _remove_?
2. Which _module(s)_ do you want to install (or remove)?

Additionally, a summary of the current status of the four modules is provided at both the beginning and the end of the script run.

_open\_webui_installer_v2.0_ is therefore also suitable for quickly installing one or more modules in a convenient way as part of other projects.

If you choose the action ```ìnstall```, the choosen modules will be automatically removed before reinstallation, if they already exist.

Of course, users need to think carefully about their actions: for example, if someone tries to stop Portainer while Docker is not installed, an error message will naturally appear.

---
## New Features of open_webui_installer_v2.1
Der _open\_webui\_installer\_v2.1_ does not introduce any new functionality. Only the helper functions have been moved into separate modules. The connection between the main script and the modules containing the helper functions is established by adding the following codeblocks to the modules and the main script:

## **(a) Helper functions modules**
Each module begins with a codeblock of the following type:

```bash
# Module guard
if [[ "${_MODULE_DOCKER_LOADED:-}" == "1" ]]; then
  return
fi
_MODULE_DOCKER_LOADED=1
```

This block is a **module guard**. It ensures that a module is **only executed once**, even if it is loaded multiple times.

### **1. Check if the module has already been loaded**

```bash
if [[ "${_MODULE_DOCKER_LOADED:-}" == "1" ]]; then
  return
fi
```

* `${_MODULE_DOCKER_LOADED:-}` → accesses `_MODULE_DOCKER_LOADED`, or an empty string if it does not exist
* If `_MODULE_DOCKER_LOADED` is already `1` → the module has been loaded
* `return` stops execution of the module **immediately**

### **2. Mark module as loaded**

```bash
_MODULE_DOCKER_LOADED=1
```

* Sets the guard variable to `1`
* Bash will know on the next `source` that the module is already loaded

The guard is a safety mechanism to ensure a module is loaded only once, side effects occur only once and modules are idempotent, that means repeated loading has no effect, functions are defined only once. Without a guard, functions would be redefined and variables overwritten.

---

## **(b) Main Script**

```bash
# --- Import System ---
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$DIR/modules"

import() {
  for mod in "$@"; do
    # Sanitize module name for Bash variable
    safe_mod="${mod^^}"        # Uppercase
    safe_mod="${safe_mod//[^A-Z0-9_]/_}"  # Replace anything not A-Z,0-9,_ with _

    guard_var="_MODULE_${safe_mod}_LOADED"

    # Check if already loaded
    if [[ "${!guard_var:-}" == "1" ]]; then
      continue
    fi

    file="$MODULE_DIR/${mod}.sh"
    if [[ ! -f "$file" ]]; then
      printf 'ERROR: module not found: %s\n' "$file" >&2
      exit 1
    fi

    # Load the module
    source "$file"

    # Mark as loaded
    declare -g "${guard_var}=1"
  done
}
```

### **1. Preparations**

```bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$DIR/modules"
```

* `DIR` = directory where the current script is located
* `MODULE_DIR` = subfolder `modules/` containing the module files

### **2. Sanitize module name**

```bash
safe_mod="${mod^^}"                 # uppercase
safe_mod="${safe_mod//[^A-Z0-9_]/_}" # everything except A–Z, 0–9, _ → _
guard_var="_MODULE_${safe_mod}_LOADED"
```

* Creates a guard variable in order to check if the module was already loaded, e.g.:

  `docker` → `_MODULE_DOCKER_LOADED`
  
  `00-bootstrap` → `_MODULE_00_BOOTSTRAP_LOADED`

### **3. Check if module is already loaded**

```bash
if [[ "${!guard_var:-}" == "1" ]]; then
  continue
fi
```

* `${!guard_var}` accesses the value of the dynamically constructed variable
* If it's already `1`, the module is **skipped** → idempotent

### **5. Path to the module file**

```bash
file="$MODULE_DIR/${mod}.sh"
if [[ ! -f "$file" ]]; then
  printf 'ERROR: module not found: %s\n' "$file" >&2
  exit 1
fi
```

* Verifies that the file exists
* If not → script aborts

### **5. Load module**

```bash
source "$file"
```

* Executes the entire module file **in the current shell context**
* All functions/variables become globally available

### **6. Set guard**

```bash
declare -g "${guard_var}=1"
```

* Marks the module as loaded
* Prevents repeated loading on subsequent `import` calls

### **Summary**

* `import()` loads **any number of modules** from `modules/`
* Modules are loaded **only once** (guard)
* Missing modules → script aborts
* Module functions/variables become **globally available**

---

## New Feature of open_webui_installer_v2.2

The function `show_final_status()` produces a final system status report and displays it in a dialog textbox at the end of each scriptrun.

```bash
show_final_status() {
    STATUS_TMPFILE="$(mktemp /tmp/status.XXXXXX)"
    STATUS_MSG="=== Final system status ===\n\n"

    # Docker
    if command -v docker >/dev/null 2>&1; then
        STATUS_MSG+="✔ Docker: installed\n"
    else
        STATUS_MSG+="• Docker: not installed\n"
    fi

[...]
    
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
```

### 1. **Create a temporary file**

   ```bash
   STATUS_TMPFILE="$(mktemp /tmp/status.XXXXXX)"
   ```

   A unique temporary file is generated to store the status output.

### 2. **Initialize the status message**

   ```bash
   STATUS_MSG="=== Final system status ===\n\n"
   ```

   This sets the header for the status report.

### 3. **Check whether Docker is installed**

   ```bash
   if command -v docker >/dev/null 2>&1; then
       STATUS_MSG+="✔ Docker: installed\n"
   else
       STATUS_MSG+="• Docker: not installed\n"
   fi
   ```

   `command -v docker` determines whether the `docker` binary exists.\
   The result (“installed” or “not installed”) is appended to `STATUS_MSG`.

### 4. **Append timestamp and footer**

   ```bash
   STATUS_MSG+="\nTime: $(date '+%Y-%m-%d %H:%M:%S')\n"
   STATUS_MSG+="=============================\n"
   ```

   Adds the current time and a closing separator.

### 5. **Write the status message to the temporary file**

   ```bash
   printf "%b" "$STATUS_MSG" > "$STATUS_TMPFILE"
   ```

   `%b` ensures escape sequences like `\n` are interpreted correctly.

### 6. **Display the status in a dialog textbox**

   ```bash
   dialog --exit-label "OK" --title "System Status" --textbox "$STATUS_TMPFILE" 0 40
   ```

   Shows a scrollable dialog window with the content of the temporary file.

### 7. **Remove the temporary file**

   ```bash
   rm -f "$STATUS_TMPFILE"
   ```

   Cleans up after displaying the dialog.


## Troubleshooting

Due to the compatibility fix, Portainer will be ```running``` but not ```healthy```.
Functionally it works; to have it ```healthy```, use Docker 28 and comment out the fix in the script.

On the very first start, eventually the open-webui container needs to be restarted again, or you may even need to perform a reboot, to jump to ```healthy```. The loading glitches of the Open WebUI container occur only when a new image is pulled — that is, when Docker has been freshly installed. If an image is already present, the container quickly switches to ```healthy```.

