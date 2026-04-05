#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# install_docker.sh
#
# Installs Docker on macOS (via Homebrew + Colima) or Ubuntu (via apt).
# On macOS, sets up a LaunchAgent so Colima starts automatically on reboot.
#
# Usage:
#   chmod +x install_docker.sh
#   ./install_docker.sh
#
# Options (macOS/Colima only):
#   COLIMA_CPU=4          CPU cores for the VM       (default: 2)
#   COLIMA_MEMORY=8       Memory in GB for the VM    (default: 4)
#   COLIMA_DISK=60        Disk size in GB for the VM (default: 60)
#   COLIMA_VMTYPE=vz      VM type: vz or qemu        (default: vz)
#
# Example:
#   COLIMA_CPU=4 COLIMA_MEMORY=8 ./install_docker.sh
# ──────────────────────────────────────────────────────────────────────────────

COLIMA_CPU="${COLIMA_CPU:-2}"
COLIMA_MEMORY="${COLIMA_MEMORY:-4}"
COLIMA_DISK="${COLIMA_DISK:-60}"
COLIMA_VMTYPE="${COLIMA_VMTYPE:-vz}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ──────────────────────────────────────────────────────────────────────────────
# macOS install
# ──────────────────────────────────────────────────────────────────────────────
install_macos() {
    info "Detected macOS"

    # --- Homebrew ---
    if ! command -v brew &>/dev/null; then
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add brew to PATH for this session
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else
        info "Homebrew already installed"
    fi

    BREW_PREFIX="$(brew --prefix)"

    # --- Docker CLI + Compose ---
    if ! command -v docker &>/dev/null; then
        info "Installing docker and docker-compose via brew..."
        brew install docker docker-compose
    else
        info "Docker CLI already installed"
    fi

    # --- Colima ---
    if ! command -v colima &>/dev/null; then
        info "Installing Colima..."
        brew install colima
    else
        info "Colima already installed"
    fi

    COLIMA_BIN="$(command -v colima)"

    # --- Start Colima (cleans stale state if needed) ---
    if colima status &>/dev/null; then
        info "Colima is already running"
    else
        info "Starting Colima (cpu=${COLIMA_CPU}, memory=${COLIMA_MEMORY}G, disk=${COLIMA_DISK}G, vmtype=${COLIMA_VMTYPE})..."

        # If a stale VM exists, delete it first
        if colima list -j 2>/dev/null | grep -q '"status":"Broken\|Stopped"'; then
            warn "Found stale Colima instance, deleting..."
            colima delete -f || true
        fi

        colima start \
            --cpu "$COLIMA_CPU" \
            --memory "$COLIMA_MEMORY" \
            --disk "$COLIMA_DISK" \
            --vm-type "$COLIMA_VMTYPE"
    fi

    # --- LaunchAgent for auto-start on reboot ---
    PLIST_DIR="$HOME/Library/LaunchAgents"
    PLIST_FILE="$PLIST_DIR/com.colima.start.plist"

    mkdir -p "$PLIST_DIR"

    info "Creating LaunchAgent at ${PLIST_FILE}..."
    cat > "$PLIST_FILE" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://plist.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.colima.start</string>
    <key>ProgramArguments</key>
    <array>
        <string>${COLIMA_BIN}</string>
        <string>start</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/tmp/colima-launchagent.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/colima-launchagent.stderr.log</string>
</dict>
</plist>
PLIST

    # Unload first if already loaded, then load
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    launchctl load "$PLIST_FILE"
    info "LaunchAgent loaded — Colima will auto-start on reboot"

    # --- Docker Compose CLI plugin (if not already wired) ---
    DOCKER_CLI_PLUGINS="$HOME/.docker/cli-plugins"
    if [[ ! -L "$DOCKER_CLI_PLUGINS/docker-compose" ]]; then
        mkdir -p "$DOCKER_CLI_PLUGINS"
        COMPOSE_BIN="$(brew --prefix docker-compose)/bin/docker-compose"
        if [[ -f "$COMPOSE_BIN" ]]; then
            ln -sfn "$COMPOSE_BIN" "$DOCKER_CLI_PLUGINS/docker-compose"
            info "Linked docker-compose as Docker CLI plugin"
        fi
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Ubuntu install
# ──────────────────────────────────────────────────────────────────────────────
install_ubuntu() {
    info "Detected Ubuntu/Debian"

    # --- Remove old/conflicting packages ---
    info "Removing any old Docker packages..."
    sudo apt-get remove -y \
        docker docker-engine docker.io containerd runc 2>/dev/null || true

    # --- Prerequisites ---
    info "Installing prerequisites..."
    sudo apt-get update
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # --- Docker GPG key ---
    KEYRINGS_DIR="/etc/apt/keyrings"
    sudo install -m 0755 -d "$KEYRINGS_DIR"

    if [[ ! -f "$KEYRINGS_DIR/docker.asc" ]]; then
        info "Adding Docker GPG key..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
            sudo tee "$KEYRINGS_DIR/docker.asc" > /dev/null
        sudo chmod a+r "$KEYRINGS_DIR/docker.asc"
    fi

    # --- Docker apt repo ---
    ARCH="$(dpkg --print-architecture)"
    CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"

    info "Adding Docker apt repository..."
    echo \
        "deb [arch=${ARCH} signed-by=${KEYRINGS_DIR}/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # --- Install Docker Engine ---
    info "Installing Docker Engine..."
    sudo apt-get update
    sudo apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    # --- Enable and start ---
    info "Enabling Docker service..."
    sudo systemctl enable docker
    sudo systemctl start docker

    # --- Add current user to docker group ---
    if ! groups "$USER" | grep -q '\bdocker\b'; then
        info "Adding $USER to the docker group..."
        sudo usermod -aG docker "$USER"
        warn "You'll need to log out and back in (or run 'newgrp docker') for group changes to take effect"
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────────────
main() {
    OS="$(uname -s)"

    case "$OS" in
        Darwin)
            install_macos
            ;;
        Linux)
            if [[ -f /etc/os-release ]] && grep -qi 'ubuntu\|debian' /etc/os-release; then
                install_ubuntu
            else
                error "Unsupported Linux distribution. This script supports Ubuntu/Debian."
            fi
            ;;
        *)
            error "Unsupported OS: ${OS}"
            ;;
    esac

    # --- Verify ---
    info "Verifying Docker installation..."
    if docker info &>/dev/null; then
        info "Docker is running!"
        docker --version
        docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || true
    else
        warn "Docker installed but daemon not reachable yet."
        warn "On Ubuntu, try: newgrp docker"
        warn "On macOS, check: colima status"
    fi

    echo ""
    info "Done!"
}

main "$@"