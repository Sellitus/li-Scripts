#!/bin/bash

# Ubuntu Ultimate Setup Script v3.0
# Enhanced with better error handling, efficient package management, and configurable options

set -euo pipefail

# Color definitions for beautiful CLI output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Unicode characters for visual elements
CHECK_MARK="✓"
CROSS_MARK="✗"
ARROW="➜"
PACKAGE="📦"
SECURITY="🔒"
GEAR="⚙️"
ROCKET="🚀"
INFO="ℹ️"
WARNING="⚠️"

# Script version
SCRIPT_VERSION="3.0"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}${CROSS_MARK} This script must be run as root${NC}"
    echo -e "${YELLOW}${ARROW} Try: sudo $0 $@${NC}"
    exit 1
fi

# Configuration with defaults
declare -A CONFIG=(
    [TIMEZONE]="${TIMEZONE:-America/Chicago}"
    [PYTHON_VERSION]="${PYTHON_VERSION:-3.12}"
    [GO_VERSION]="${GO_VERSION:-1.21.5}"
    [NODE_VERSION]="${NODE_VERSION:-lts}"
    [BACKUP_DIR]="${BACKUP_DIR:-/var/backups/ubuntu-setup}"
    [LOG_FILE]="${LOG_FILE:-/var/log/ubuntu-setup.log}"
    [GIT_EMAIL]="${GIT_EMAIL:-user@example.com}"
    [GIT_NAME]="${GIT_NAME:-User}"
    [SSH_KEY]="${SSH_KEY:-}"
    [PACKAGE_TIMEOUT]="${PACKAGE_TIMEOUT:-300}"
    [RETRY_ATTEMPTS]="${RETRY_ATTEMPTS:-3}"
    [BATCH_SIZE]="${BATCH_SIZE:-10}"
)

# Arrays to track installation status
declare -a FAILED_PACKAGES=()
declare -a INSTALLED_PACKAGES=()
declare -a SKIPPED_PACKAGES=()

# Package groups
systemApps="vim neovim tmux curl wget nano build-essential cmake make gcc g++ unzip zip ufw fail2ban git git-lfs sysbench htop iotop nethogs fish zsh bat ripgrep fd-find fzf jq yq virtualenv python3-venv python3-pip docker.io docker-compose containerd snapd flatpak gpg apt-transport-https software-properties-common ca-certificates gnupg lsb-release net-tools dnsutils whois traceroute mtr-tiny nmap tcpdump iftop vnstat bmon nload speedtest-cli tree ncdu tldr exa duf neofetch"

# Note: tripwire removed as it requires interactive configuration
securityApps="aide rkhunter chkrootkit clamav clamav-daemon lynis tiger samhain auditd apparmor-utils libpam-pwquality unattended-upgrades apt-listchanges needrestart debsecan debsums fail2ban psad"

serverApps="openssh-server nginx certbot python3-certbot-nginx"

guiApps="qbittorrent sublime-text sublime-merge tilix firefox chromium-browser git-cola gitg meld"

mateDesktop="mate-desktop-environment mate-desktop-environment-extras ubuntu-mate-themes"

vmGuestAdditions="open-vm-tools open-vm-tools-desktop"

hyperVGuestAdditions="linux-virtual linux-cloud-tools-virtual linux-tools-virtual"

containerTools="kubectl minikube helm k9s"

developmentTools="golang-go nodejs npm yarn redis-tools postgresql-client mysql-client mongodb-clients sqlite3 httpie insomnia postman"

# Function to print colored headers
print_header() {
    local header=$1
    local width=80
    local padding=$(( (width - ${#header} - 2) / 2 ))
    
    echo
    echo -e "${CYAN}$(printf '═%.0s' {1..80})${NC}"
    echo -e "${CYAN}║${NC}$(printf ' %.0s' $(seq 1 $padding))${BOLD}${WHITE}$header${NC}$(printf ' %.0s' $(seq 1 $padding))${CYAN}║${NC}"
    echo -e "${CYAN}$(printf '═%.0s' {1..80})${NC}"
    echo
}

# Function to print status messages
print_status() {
    echo -e "${BLUE}${ARROW}${NC} $1"
}

print_success() {
    echo -e "${GREEN}${CHECK_MARK}${NC} $1"
}

print_error() {
    echo -e "${RED}${CROSS_MARK}${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}${WARNING}${NC} $1"
}

print_info() {
    echo -e "${CYAN}${INFO}${NC} $1"
}

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    
    printf "\r["
    printf "%${completed}s" | tr ' ' '█'
    printf "%$((width - completed))s" | tr ' ' '░'
    printf "] %d%%" $percentage
}

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${CONFIG[LOG_FILE]}"
}

# Check if package is installed
is_package_installed() {
    local package="$1"
    set +e  # Temporarily disable exit on error
    dpkg -l "$package" 2>/dev/null | grep -q "^ii"
    local result=$?
    set -e  # Re-enable exit on error
    return $result
}

# Install packages with retry logic
install_package() {
    local package=$1
    local attempts=0
    local max_attempts="${CONFIG[RETRY_ATTEMPTS]}"
    
    # Check if already installed
    if is_package_installed "$package"; then
        SKIPPED_PACKAGES+=("$package")
        return 0
    fi
    
    while [ $attempts -lt $max_attempts ]; do
        attempts=$((attempts + 1))
        
        # Temporarily disable exit on error for package installation
        set +e
        timeout "${CONFIG[PACKAGE_TIMEOUT]}" apt-get install -y -q \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            "$package" >/dev/null 2>&1
        local install_result=$?
        set -e
        
        if [ $install_result -eq 0 ]; then
            INSTALLED_PACKAGES+=("$package")
            return 0
        fi
        
        # If it's the last attempt, check if it was actually installed
        if [ $attempts -eq $max_attempts ]; then
            if is_package_installed "$package"; then
                INSTALLED_PACKAGES+=("$package")
                return 0
            fi
            # Log the failure for debugging
            log "Failed to install package: $package after $max_attempts attempts"
        fi
        
        # Wait before retry
        sleep 2
    done
    
    FAILED_PACKAGES+=("$package")
    return 1
}

# Batch install packages - SIMPLIFIED VERSION
batch_install_packages() {
    local packages=("$@")
    local total=${#packages[@]}
    
    print_status "Installing ${total} packages..."
    
    # Update package cache
    apt-get update -qq || true
    
    # Just try to install everything, don't worry about checking what's installed
    print_status "Installing packages with apt..."
    
    set +e
    apt-get install -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        "${packages[@]}"
    local result=$?
    set -e
    
    if [ $result -eq 0 ]; then
        print_success "Package installation completed successfully"
        INSTALLED_PACKAGES+=("${packages[@]}")
    else
        print_warning "Some packages may have failed to install (exit code: $result)"
        print_status "Continuing with script execution..."
    fi
}

# Pre-configure packages that require interaction
preconfigure_packages() {
    print_status "Pre-configuring packages to avoid prompts..."
    
    # Configure postfix
    echo "postfix postfix/main_mailer_type select Local only" | debconf-set-selections
    echo "postfix postfix/mailname string $(hostname)" | debconf-set-selections
    
    # Configure other packages that might prompt
    echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
    echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
    echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
    
    print_success "Package pre-configuration complete"
}

# Load configuration from file if exists
load_config_file() {
    local config_file="${1:-/etc/ubuntu-setup.conf}"
    if [ -f "$config_file" ]; then
        print_info "Loading configuration from $config_file"
        source "$config_file"
    fi
}

# Backup function
create_backup() {
    print_status "Creating system backup..."
    
    local backup_name="ubuntu-setup-$(date +%Y%m%d-%H%M%S)"
    local backup_path="${CONFIG[BACKUP_DIR]}/$backup_name"
    
    mkdir -p "${CONFIG[BACKUP_DIR]}"
    
    # Backup critical system files
    local files_to_backup=(
        "/etc/apt/sources.list"
        "/etc/apt/sources.list.d/"
        "/etc/ssh/sshd_config"
        "/etc/ufw/"
        "/etc/fail2ban/"
        "/home/*/.bashrc"
        "/home/*/.profile"
    )
    
    tar -czf "$backup_path.tar.gz" ${files_to_backup[@]} 2>/dev/null || true
    
    print_success "Backup created at: $backup_path.tar.gz"
    log "Backup created: $backup_path.tar.gz"
}

# Function to check if running in WSL
detect_wsl() {
    if grep -qiE "(microsoft|wsl)" /proc/version; then
        return 0
    else
        return 1
    fi
}

# Clean up problematic repositories
cleanup_repositories() {
    print_status "Cleaning up old repository configurations..."
    
    # Remove old Kubernetes repositories
    rm -f /etc/apt/sources.list.d/kubernetes*.list
    rm -f /usr/share/keyrings/kubernetes*.gpg
    
    # Remove any references to old kubernetes repositories
    if [ -f /etc/apt/sources.list ]; then
        sed -i '/apt\.kubernetes\.io/d' /etc/apt/sources.list
        sed -i '/packages\.cloud\.google\.com\/apt.*kubernetes/d' /etc/apt/sources.list
    fi
    
    # Clean apt cache
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    
    print_success "Repository cleanup complete"
}

# Install Python with better error handling
install_python() {
    local python_version="${CONFIG[PYTHON_VERSION]}"
    
    print_status "Installing Python ${python_version}..."
    
    # Add deadsnakes PPA
    if ! add-apt-repository -y ppa:deadsnakes/ppa; then
        print_error "Failed to add Python PPA"
        return 1
    fi
    
    apt-get update -qq
    
    # Install Python packages
    local python_packages=(
        "python${python_version}"
        "python${python_version}-venv"
        "python${python_version}-dev"
        "python${python_version}-distutils"
    )
    
    for pkg in "${python_packages[@]}"; do
        if ! apt-get install -y "$pkg"; then
            print_warning "Failed to install $pkg"
        fi
    done
    
    # Set as default Python 3
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${python_version} 1
    update-alternatives --set python3 /usr/bin/python${python_version}
    
    # Install pip
    print_status "Installing pip..."
    if ! command -v pip3 &> /dev/null; then
        if curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py; then
            # Install pip properly
            python3 /tmp/get-pip.py --user 2>/dev/null || \
            python3 /tmp/get-pip.py 2>/dev/null || \
            print_warning "Failed to install pip normally, trying with break-system-packages..."
            
            # If still no pip, try with break-system-packages
            if ! command -v pip3 &> /dev/null; then
                python3 /tmp/get-pip.py --break-system-packages 2>/dev/null || \
                print_error "Failed to install pip"
            fi
            
            rm -f /tmp/get-pip.py
        fi
    fi
    
    # Install pipx
    if apt-get install -y pipx; then
        print_success "pipx installed"
    else
        print_warning "Failed to install pipx"
    fi
    
    print_success "Python ${python_version} setup complete"
}

# Initialize script
initialize_script() {
    # Create log directory
    mkdir -p "$(dirname "${CONFIG[LOG_FILE]}")"
    
    # Start logging
    log "Ubuntu Setup Script v${SCRIPT_VERSION} started"
    
    # Set DEBIAN_FRONTEND for the entire script
    export DEBIAN_FRONTEND=noninteractive
    
    # Load config file if specified
    if [ -n "${CONFIG_FILE:-}" ]; then
        load_config_file "$CONFIG_FILE"
    fi
}

# Print installation summary
print_installation_summary() {
    echo
    print_header "Installation Summary"
    
    if [ ${#INSTALLED_PACKAGES[@]} -gt 0 ]; then
        echo -e "${GREEN}${BOLD}Successfully Installed (${#INSTALLED_PACKAGES[@]} packages):${NC}"
        printf '%s\n' "${INSTALLED_PACKAGES[@]}" | sort | column -c 80
        echo
    fi
    
    if [ ${#SKIPPED_PACKAGES[@]} -gt 0 ]; then
        echo -e "${CYAN}${BOLD}Already Installed/Skipped (${#SKIPPED_PACKAGES[@]} packages):${NC}"
        printf '%s\n' "${SKIPPED_PACKAGES[@]}" | sort | column -c 80
        echo
    fi
    
    if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
        echo -e "${RED}${BOLD}Failed to Install (${#FAILED_PACKAGES[@]} packages):${NC}"
        printf '%s\n' "${FAILED_PACKAGES[@]}" | sort | column -c 80
        echo
        print_warning "You can try installing failed packages manually with:"
        echo -e "${YELLOW}sudo apt install ${FAILED_PACKAGES[*]}${NC}"
        echo
    fi
}

# Enhanced menu display
display_menu() {
    clear
    echo -e "${BOLD}${MAGENTA}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║           Ubuntu Ultimate Setup Script v3.0                   ║
    ║                                                               ║
    ║         🚀 Modern Development Environment Setup 🚀            ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "${CYAN}${BOLD}Available Options:${NC}"
    echo
    echo -e "${GREEN}1${NC} - ${BOLD}Core System Setup${NC}"
    echo -e "    ${PACKAGE} System utilities, Python ${CONFIG[PYTHON_VERSION]}, development tools"
    echo -e "    ${GEAR} Git, Docker, Kubernetes tools, Node.js (via nvm), Go"
    echo
    echo -e "${GREEN}2${NC} - ${BOLD}Security Hardening${NC}"
    echo -e "    ${SECURITY} SSH hardening, firewall, intrusion detection"
    echo -e "    ${SECURITY} Anti-malware, rootkit detection, security auditing"
    echo
    echo -e "${GREEN}3${NC} - ${BOLD}Server Setup${NC}"
    echo -e "    📡 OpenSSH, Nginx, Certbot"
    echo
    echo -e "${GREEN}4${NC} - ${BOLD}MATE Desktop Environment${NC}"
    echo -e "    🖥️  Full MATE desktop with extras"
    echo
    echo -e "${GREEN}5${NC} - ${BOLD}GUI Applications${NC}"
    echo -e "    🎨 Development tools, browsers, editors"
    echo
    echo -e "${GREEN}6${NC} - ${BOLD}VMware/VirtualBox Guest Additions${NC}"
    echo
    echo -e "${GREEN}7${NC} - ${BOLD}Hyper-V Guest Additions${NC}"
    echo
    echo -e "${GREEN}8${NC} - ${BOLD}WSL Fixes${NC} (requires restart)"
    echo
    echo -e "${GREEN}9${NC} - ${BOLD}Skip Reboot${NC} at end"
    echo
    echo -e "${YELLOW}${BOLD}Enter your choices separated by commas (e.g., 1,2,3):${NC}"
}

# Main script starts here
initialize_script

# Initialize choices
basicChoice=""
securityChoice=""
serverChoice=""
mateChoice=""
guiChoice=""
vmGuestChoice=""
hyperVGuestChoice=""
wslFix=""
preventRebootChoice=""
username=""

# Get user input
userInput="${1:-}"
if [[ -z "$userInput" ]]; then
    display_menu
    read -p "$(echo -e ${CYAN}${ARROW}${NC} ) " userInput
fi

# Parse user choices
IFS=',' read -ra CHOICES <<< "$userInput"
for choice in "${CHOICES[@]}"; do
    case $choice in
        1) basicChoice="y" ;;
        2) securityChoice="y" ;;
        3) serverChoice="y" ;;
        4) mateChoice="y" ;;
        5) guiChoice="y" ;;
        6) vmGuestChoice="y" ;;
        7) hyperVGuestChoice="y" ;;
        8) wslFix="y" ;;
        9) preventRebootChoice="y" ;;
    esac
done

# WSL detection and fixes
if [[ $wslFix == "y" ]] && detect_wsl; then
    print_header "WSL Fixes"
    print_status "Applying WSL-specific fixes..."
    
    apt-get update
    apt-get install -y daemonize dbus-user-session fontconfig libsquashfuse0 squashfuse fuse snapd
    
    print_warning "WSL will restart after fixes are applied"
    daemonize /usr/bin/unshare --fork --pid --mount-proc /lib/systemd/systemd --system-unit=basic.target
    exec nsenter -t $(pidof systemd) -a su - $LOGNAME
    wsl.exe --shutdown
fi

# Basic System Setup
if [[ $basicChoice == "y" ]]; then
    print_header "Core System Setup"
    
    # Clean up repositories
    cleanup_repositories
    
    # Create backup
    create_backup
    
    # Get username
    while true; do
        echo -e "${CYAN}Enter username to create/configure (with sudo access):${NC}"
        read -p "$(echo -e ${CYAN}${ARROW}${NC} ) " username
        username="$(echo -e "${username}" | tr -d '[:space:]')"
        
        echo -e "${YELLOW}Create/configure user: ${BOLD}$username${NC}? [Y/n]"
        read -p "$(echo -e ${CYAN}${ARROW}${NC} ) " confirm
        
        if [[ -z $confirm || $confirm =~ ^[Yy]$ ]]; then
            break
        fi
    done
    
    print_status "Setting up user: $username"
    if ! id "$username" &>/dev/null; then
        adduser --gecos "" "$username"
    fi
    usermod -aG sudo "$username"
    print_success "User configured"
    
    # Change root password
    echo -e "${YELLOW}Change ROOT password? [y/N]${NC}"
    read -p "$(echo -e ${CYAN}${ARROW}${NC} ) " rootPassChoice
    if [[ $rootPassChoice =~ ^[Yy]$ ]]; then
        passwd root
    fi
    
    # Set timezone
    print_status "Setting timezone to ${CONFIG[TIMEZONE]}"
    timedatectl set-timezone "${CONFIG[TIMEZONE]}"
    print_success "Timezone configured"
    
    # Configure shell environment
    print_status "Configuring shell environment"
    
    # Enhanced .bashrc
    cat > "/home/$username/.bashrc" << 'EOL'
# Enhanced .bashrc for Ubuntu Ultimate Setup

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# History settings
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend

# Window size check
shopt -s checkwinsize

# Enable color support
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Modern aliases
alias ll='exa -la --git --icons'
alias la='exa -a --icons'
alias l='exa --icons'
alias tree='exa --tree --icons'
alias cat='batcat'
alias df='duf'
alias du='ncdu'
alias top='htop'
alias vim='nvim'
alias vi='nvim'
alias python='python3'
alias pip='pip3'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'
alias lg='lazygit'

# Docker aliases
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias di='docker images'

# Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'

# Tmux session helpers
for i in {1..10}; do
    eval "function tmux$i() { tmux attach-session -t main$i || tmux new-session -s main$i; }"
done

# Python virtual environment helpers
mkvenv() {
    python3 -m venv "${1:-venv}"
    source "${1:-venv}/bin/activate"
}

activate() {
    source "${1:-venv}/bin/activate"
}

# Colored prompt
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Enable programmable completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Go
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin

# Local binaries and pip/pipx
export PATH=$HOME/.local/bin:$PATH

# Pipx
export PATH="$PATH:/home/$USER/.local/bin"

# FZF
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

neofetch
EOL
    
    chown "$username:$username" "/home/$username/.bashrc"
    print_success "Shell environment configured"
    
    # Pre-configure packages
    preconfigure_packages
    
    # System updates
    print_status "Updating system packages..."
    apt-get update
    apt-get full-upgrade -y -q
    
    # Install base packages
    print_status "Installing system packages..."
    systemApps_array=($systemApps)
    batch_install_packages "${systemApps_array[@]}"
    
    # Install Python
    install_python
    
    # Install pipx for user
    if command -v pipx &> /dev/null; then
        sudo -u $username pipx ensurepath || true
    fi
    
    # Install Node.js via NVM
    print_status "Installing Node.js via NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | sudo -u $username bash
    
    # Install Node.js LTS
    sudo -u $username bash -c "source /home/$username/.nvm/nvm.sh && nvm install --lts && nvm use --lts && nvm alias default node"
    print_success "Node.js installed via NVM"
    
    # Install Go
    print_status "Installing Go ${CONFIG[GO_VERSION]}..."
    if wget -q "https://go.dev/dl/go${CONFIG[GO_VERSION]}.linux-amd64.tar.gz" -O /tmp/go.tar.gz; then
        rm -rf /usr/local/go
        tar -C /usr/local -xzf /tmp/go.tar.gz
        rm /tmp/go.tar.gz
        
        # Verify Go installation
        export PATH=$PATH:/usr/local/go/bin
        if /usr/local/go/bin/go version &>/dev/null; then
            print_success "Go ${CONFIG[GO_VERSION]} installed"
        else
            print_warning "Go installation may have failed"
        fi
    else
        print_warning "Failed to download Go ${CONFIG[GO_VERSION]}"
    fi
    
    # Install Docker
    print_status "Installing Docker and container tools..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add user to docker group
    usermod -aG docker "$username"
    print_success "User added to docker group"
    
    # Install Kubernetes tools
    print_status "Installing Kubernetes tools..."
    
    # Remove old Kubernetes repository if it exists
    rm -f /etc/apt/sources.list.d/kubernetes.list
    rm -f /usr/share/keyrings/kubernetes-archive-keyring.gpg
    
    # Add the new Kubernetes apt repository
    if curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-apt-keyring.gpg 2>/dev/null; then
        echo "deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
        print_success "Kubernetes repository added"
    else
        print_warning "Failed to add Kubernetes repository key"
    fi
    
    if apt update; then
        apt install -y kubectl || print_warning "Failed to install kubectl"
    else
        print_warning "Failed to update package lists after adding Kubernetes repository"
    fi
    
    # Install minikube
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    install minikube-linux-amd64 /usr/local/bin/minikube
    rm minikube-linux-amd64
    
    # Install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    # Install k9s
    wget -q https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz -O /tmp/k9s.tar.gz
    tar -xzf /tmp/k9s.tar.gz -C /tmp/
    mv /tmp/k9s /usr/local/bin/
    rm /tmp/k9s.tar.gz
    
    print_success "Docker and container tools installed"
    
    # Install development tools
    print_status "Installing additional development tools..."
    
    # LazyGit
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar -xzf /tmp/lazygit.tar.gz -C /usr/local/bin/
    rm /tmp/lazygit.tar.gz
    
    # Install Go development tools
    # Export Go path for the current session
    export PATH=$PATH:/usr/local/go/bin
    
    # Install tools with proper PATH
    sudo -u $username bash -c "export PATH=$PATH:/usr/local/go/bin && go install golang.org/x/tools/gopls@latest" || print_warning "Failed to install gopls"
    sudo -u $username bash -c "export PATH=$PATH:/usr/local/go/bin && go install github.com/go-delve/delve/cmd/dlv@latest" || print_warning "Failed to install dlv"
    sudo -u $username bash -c "export PATH=$PATH:/usr/local/go/bin && go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest" || print_warning "Failed to install golangci-lint"
    
    # Install Node.js global packages
    sudo -u $username bash -c "source /home/$username/.nvm/nvm.sh && npm install -g yarn pnpm typescript ts-node nodemon pm2 eslint prettier"
    
    print_success "Development tools installed"
    
    # Configure Git
    print_status "Configuring Git..."
    sudo -u $username git config --global user.email "sellitus@gmail.com"
    sudo -u $username git config --global user.name "Sellitus"
    sudo -u $username git config --global push.default simple
    sudo -u $username git config --global init.defaultBranch main
    sudo -u $username git config --global core.editor nvim
    print_success "Git configured"
    
    # Final cleanup
    print_status "Cleaning up..."
    apt autoremove -y
    apt autoclean -y
    print_success "Core system setup complete"
fi

# Security Hardening
if [[ $securityChoice == "y" ]]; then
    print_header "Security Hardening"
    
    # Pre-configure security packages
    preconfigure_packages
    
    # Install security packages using batch installer
    print_status "Installing security tools..."
    securityApps_array=($securityApps)
    batch_install_packages "${securityApps_array[@]}"
    
    # Configure UFW
    print_status "Configuring firewall..."
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp comment 'SSH'
    ufw limit 22/tcp
    ufw --force enable
    print_success "Firewall configured"
    
    # Configure Fail2ban
    print_status "Configuring Fail2ban..."
    cat > /etc/fail2ban/jail.local << 'EOL'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = root@localhost
sendername = Fail2Ban
action = %(action_mwl)s

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200
EOL
    
    systemctl enable fail2ban
    systemctl restart fail2ban
    print_success "Fail2ban configured"
    
    # Configure AIDE
    print_status "Configuring AIDE..."
    aideinit
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    print_success "AIDE initialized"
    
    # Configure rkhunter
    print_status "Configuring rkhunter..."
    rkhunter --update
    rkhunter --propupd
    
    # Configure ClamAV
    print_status "Configuring ClamAV..."
    systemctl stop clamav-freshclam
    freshclam
    systemctl start clamav-freshclam
    systemctl enable clamav-daemon
    
    # Configure auditd
    print_status "Configuring auditd..."
    cat >> /etc/audit/rules.d/audit.rules << 'EOL'
# Monitor sudo usage
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes

# Monitor user/group changes
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k shadow_changes

# Monitor SSH configuration
-w /etc/ssh/sshd_config -p wa -k sshd_config

# Monitor system calls
-a exit,always -F arch=b64 -S execve -k exec
-a exit,always -F arch=b32 -S execve -k exec
EOL
    
    service auditd restart
    print_success "Auditd configured"
    
    # Configure automatic security updates
    print_status "Configuring automatic security updates..."
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOL'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
EOL
    
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOL'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOL
    
    print_success "Automatic security updates configured"
    
    # System hardening
    print_status "Applying system hardening..."
    
    # Kernel hardening via sysctl
    cat >> /etc/sysctl.d/99-security.conf << 'EOL'
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Log Martians
net.ipv4.conf.all.log_martians = 1

# Ignore ICMP ping requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore Directed pings
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Accept ICMP redirects only for gateways listed in default gateway list
net.ipv4.conf.all.secure_redirects = 1

# Do not accept IP source route packets
net.ipv4.conf.all.accept_source_route = 0

# Protect against tcp time-wait assassination hazards
net.ipv4.tcp_rfc1337 = 1

# Decrease the time default value for tcp_fin_timeout connection
net.ipv4.tcp_fin_timeout = 15

# Decrease the time default value for connections to keep alive
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# Enable ExecShield protection
kernel.randomize_va_space = 2

# Increase system file descriptor limit
fs.file-max = 65535

# Allow for more PIDs
kernel.pid_max = 65535

# Increase system IP port limits
net.ipv4.ip_local_port_range = 2000 65000
EOL
    
    sysctl -p /etc/sysctl.d/99-security.conf
    
    # Configure password quality
    apt install -y libpam-pwquality
    sed -i 's/# minlen = 8/minlen = 12/' /etc/security/pwquality.conf
    sed -i 's/# ucredit = -1/ucredit = -1/' /etc/security/pwquality.conf
    sed -i 's/# lcredit = -1/lcredit = -1/' /etc/security/pwquality.conf
    sed -i 's/# dcredit = -1/dcredit = -1/' /etc/security/pwquality.conf
    sed -i 's/# ocredit = -1/ocredit = -1/' /etc/security/pwquality.conf
    
    print_success "System hardening applied"
    
    # Setup security scanning cron jobs
    print_status "Setting up automated security scans..."
    
    cat > /etc/cron.daily/security-scans << 'EOL'
#!/bin/bash
# Daily security scans

# Update security databases
freshclam > /dev/null 2>&1
rkhunter --update > /dev/null 2>&1

# Run scans
clamscan -r / --quiet --infected --log=/var/log/clamav/daily-scan.log
rkhunter --check --skip-keypress --quiet
lynis audit system --quiet

# Check for security updates
/usr/lib/update-notifier/apt-check --human-readable > /var/log/security-updates.log
EOL
    
    chmod +x /etc/cron.daily/security-scans
    
    print_success "Automated security scans configured"
    
    # Tripwire installation notice
    echo
    print_warning "Note: Tripwire was not installed automatically as it requires interactive configuration."
    print_status "To install Tripwire manually, run:"
    echo -e "${CYAN}    sudo apt install tripwire${NC}"
    echo -e "${CYAN}    # You will be prompted to set site and local passphrases${NC}"
    echo
    
    print_success "Security hardening complete"
fi

# Server Setup
if [[ $serverChoice == "y" ]]; then
    print_header "Server Setup"
    
    print_status "Installing server packages..."
    for package in $serverApps; do
        apt install -y "$package" || print_warning "Failed to install $package"
    done
    
    # SSH Hardening
    print_status "Hardening SSH configuration..."
    
    # Backup original SSH config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Generate SSH keys for user
    sudo -u $username mkdir -p "/home/$username/.ssh"
    sudo -u $username chmod 700 "/home/$username/.ssh"
    
    # Add your public key
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPuPn0cnBDl7BOEecgcbrWvM+dIBuKZZaRYRMqoYv2Aw sellitus@ss-MacBook-Pro.local" > "/home/$username/.ssh/authorized_keys"
    chown "$username:$username" "/home/$username/.ssh/authorized_keys"
    chmod 600 "/home/$username/.ssh/authorized_keys"
    
    # Create hardened SSH config
    cat > /etc/ssh/sshd_config.d/99-hardened.conf << EOL
# Hardened SSH Configuration
Protocol 2
Port 22
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key

# Authentication
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
AuthenticationMethods publickey
AllowUsers $username

# Security
PermitEmptyPasswords no
X11Forwarding no
IgnoreRhosts yes
HostbasedAuthentication no
PermitUserEnvironment no
StrictModes yes
UsePrivilegeSeparation sandbox

# Performance
UseDNS no
Compression no

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Connection limits
MaxAuthTries 3
MaxSessions 10
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 30

# Ciphers and algorithms
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
EOL
    
    # Test SSH config
    sshd -t
    if [ $? -eq 0 ]; then
        systemctl restart sshd
        print_success "SSH hardened and restarted"
    else
        print_error "SSH config test failed, keeping original"
        rm /etc/ssh/sshd_config.d/99-hardened.conf
    fi
    
    # Configure Nginx
    print_status "Configuring Nginx..."
    
    # Create a basic secure Nginx config
    cat > /etc/nginx/conf.d/security.conf << 'EOL'
# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

# Hide Nginx version
server_tokens off;

# Limit request size
client_max_body_size 10M;

# SSL Configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
EOL
    
    nginx -t && systemctl restart nginx
    print_success "Nginx configured"
    
    # Setup automatic updates cron
    print_status "Setting up automatic security updates..."
    
    (crontab -l 2>/dev/null; echo "0 6 * * * apt update && apt-get -y upgrade && apt-get -y autoremove && apt-get -y autoclean && needrestart -ra") | crontab -
    
    print_success "Server setup complete"
fi

# MATE Desktop Environment
if [[ $mateChoice == "y" ]]; then
    print_header "MATE Desktop Environment"
    
    print_status "Installing MATE desktop packages..."
    mateDesktop_array=($mateDesktop)
    batch_install_packages "${mateDesktop_array[@]}"
    
    # Install additional useful desktop utilities
    desktop_utils="pluma atril eom gnome-system-monitor dconf-editor"
    desktop_utils_array=($desktop_utils)
    batch_install_packages "${desktop_utils_array[@]}"
    
    # Configure MATE for better performance
    sudo -u $username dbus-launch dconf write /org/mate/desktop/interface/gtk-enable-animations false
    sudo -u $username dbus-launch dconf write /org/mate/marco/general/compositing-manager false
    
    print_success "MATE desktop environment installed"
fi

# GUI Applications
if [[ $guiChoice == "y" ]]; then
    print_header "GUI Applications"
    
    # Add repositories
    print_status "Adding application repositories..."
    
    # Sublime Text
    wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor | tee /etc/apt/trusted.gpg.d/sublimehq-archive.gpg > /dev/null
    echo "deb https://download.sublimetext.com/ apt/stable/" | tee /etc/apt/sources.list.d/sublime-text.list
    
    # Install GUI packages
    print_status "Installing GUI applications..."
    guiApps_array=($guiApps)
    batch_install_packages "${guiApps_array[@]}"
    
    # Install additional development IDEs via snap
    print_status "Installing development IDEs..."
    snap install code --classic
    snap install pycharm-community --classic
    snap install intellij-idea-community --classic
    snap install goland --classic || print_warning "GoLand requires license"
    
    # Install VS Code extensions
    if command -v code &> /dev/null; then
        print_status "Installing VS Code extensions..."
        
        extensions=(
            "ms-python.python"
            "ms-python.vscode-pylance"
            "ms-python.debugpy"
            "ms-toolsai.jupyter"
            "ms-toolsai.vscode-jupyter-cell-tags"
            "golang.go"
            "ms-vscode.cpptools"
            "ms-azuretools.vscode-docker"
            "ms-kubernetes-tools.vscode-kubernetes-tools"
            "hashicorp.terraform"
            "redhat.vscode-yaml"
            "esbenp.prettier-vscode"
            "dbaeumer.vscode-eslint"
            "github.copilot"
            "eamodio.gitlens"
            "mhutchie.git-graph"
            "streetsidesoftware.code-spell-checker"
            "wayou.vscode-todo-highlight"
            "gruntfuggly.todo-tree"
            "formulahendry.auto-close-tag"
            "formulahendry.auto-rename-tag"
            "christian-kohler.path-intellisense"
            "visualstudioexptteam.vscodeintellicode"
            "ms-vscode-remote.remote-ssh"
            "ms-vscode-remote.remote-containers"
            "ms-vscode-remote.vscode-remote-extensionpack"
        )
        
        for ext in "${extensions[@]}"; do
            sudo -u $username code --install-extension "$ext" || print_warning "Failed to install extension: $ext"
        done
        
        # Configure VS Code settings
        mkdir -p "/home/$username/.config/Code/User"
        cat > "/home/$username/.config/Code/User/settings.json" << 'EOL'
{
    "workbench.colorTheme": "Default Dark+",
    "editor.fontSize": 14,
    "editor.fontFamily": "'JetBrains Mono', 'Fira Code', 'Cascadia Code', Consolas, monospace",
    "editor.fontLigatures": true,
    "editor.wordWrap": "on",
    "editor.minimap.enabled": true,
    "editor.formatOnSave": true,
    "editor.formatOnPaste": true,
    "editor.suggestSelection": "first",
    "editor.snippetSuggestions": "top",
    "editor.tabSize": 4,
    "editor.detectIndentation": true,
    "editor.rulers": [80, 120],
    "editor.bracketPairColorization.enabled": true,
    "editor.guides.indentation": true,
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "workbench.editor.wrapTabs": true,
    "workbench.editor.tabSizing": "shrink",
    "terminal.integrated.fontSize": 13,
    "terminal.integrated.shell.linux": "/bin/bash",
    "git.autofetch": true,
    "git.confirmSync": false,
    "git.enableSmartCommit": true,
    "python.defaultInterpreterPath": "python3",
    "python.linting.enabled": true,
    "python.linting.pylintEnabled": true,
    "python.formatting.provider": "black",
    "go.useLanguageServer": true,
    "go.toolsManagement.autoUpdate": true,
    "[python]": {
        "editor.defaultFormatter": "ms-python.black-formatter"
    },
    "[javascript]": {
        "editor.defaultFormatter": "esbenp.prettier-vscode"
    },
    "[typescript]": {
        "editor.defaultFormatter": "esbenp.prettier-vscode"
    },
    "[json]": {
        "editor.defaultFormatter": "esbenp.prettier-vscode"
    }
}
EOL
        chown -R "$username:$username" "/home/$username/.config/Code"
    fi
    
    # Install fonts for development
    print_status "Installing development fonts..."
    apt install -y fonts-firacode fonts-cascadia-code
    
    # Install JetBrains Mono
    wget -q https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip -O /tmp/jetbrains-mono.zip
    unzip -q /tmp/jetbrains-mono.zip -d /tmp/jetbrains-mono
    mkdir -p /usr/share/fonts/truetype/jetbrains-mono
    cp /tmp/jetbrains-mono/fonts/ttf/*.ttf /usr/share/fonts/truetype/jetbrains-mono/
    fc-cache -f -v
    rm -rf /tmp/jetbrains-mono*
    
    print_success "GUI applications installed"
fi

# VM Guest Additions
if [[ $vmGuestChoice == "y" ]]; then
    print_header "VM Guest Additions"
    
    print_status "Installing VMware/VirtualBox guest additions..."
    vmGuestAdditions_array=($vmGuestAdditions)
    batch_install_packages "${vmGuestAdditions_array[@]}"
    
    print_success "VM guest additions installed"
fi

# Hyper-V Guest Additions
if [[ $hyperVGuestChoice == "y" ]]; then
    print_header "Hyper-V Guest Additions"
    
    print_status "Installing Hyper-V guest additions..."
    
    # Add Hyper-V modules to initramfs
    for module in hv_utils hv_vmbus hv_storvsc hv_blkvsc hv_netvsc; do
        echo "$module" >> /etc/initramfs-tools/modules
    done
    
    # Install packages
    hyperVGuestAdditions_array=($hyperVGuestAdditions)
    batch_install_packages "${hyperVGuestAdditions_array[@]}"
    
    # Update initramfs
    update-initramfs -u
    
    print_success "Hyper-V guest additions installed"
fi

# Final steps
if [[ $basicChoice == "y" ]] || [[ $securityChoice == "y" ]]; then
    print_header "Final Configuration"
    
    # Configure Docker to respect UFW
    if systemctl is-active docker &>/dev/null && systemctl is-active ufw &>/dev/null; then
        print_status "Configuring Docker firewall rules..."
        
        # Get default network interface
        default_interface=$(ip route | grep default | head -n 1 | awk '{print $5}')
        
        if [[ ! -f /etc/ufw/after.rules.backup ]]; then
            cp /etc/ufw/after.rules /etc/ufw/after.rules.backup
        fi
        
        # Add Docker UFW rules if not already present
        if ! grep -q "DOCKER-USER" /etc/ufw/after.rules; then
            cat >> /etc/ufw/after.rules << EOL

# BEGIN UFW AND DOCKER
*filter
:DOCKER-USER - [0:0]
:ufw-user-input - [0:0]

-A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A DOCKER-USER -m conntrack --ctstate INVALID -j DROP
-A DOCKER-USER -i $default_interface -j ufw-user-input
-A DOCKER-USER -i $default_interface -j DROP
COMMIT
# END UFW AND DOCKER
EOL
        fi
        
        systemctl restart ufw
        systemctl restart docker
        print_success "Docker firewall rules configured"
    fi
    
    # Final system cleanup
    print_status "Performing final cleanup..."
    apt-get autoremove -y
    apt-get autoclean -y
    apt-get clean
    
    # Remove unnecessary packages
    apt-get purge -y popularity-contest
    
    # Update locate database
    updatedb
    
    # Create summary log
    print_status "Creating installation summary..."
    
    cat > "/home/$username/ubuntu-setup-summary.log" << EOL
Ubuntu Ultimate Setup Script - Installation Summary
===================================================
Date: $(date)
Hostname: $(hostname)
IP Address: $(hostname -I | awk '{print $1}')
Ubuntu Version: $(lsb_release -d | cut -f2)
Kernel: $(uname -r)

Installed Components:
$(
    [[ $basicChoice == "y" ]] && echo "✓ Core System Setup"
    [[ $securityChoice == "y" ]] && echo "✓ Security Hardening"
    [[ $serverChoice == "y" ]] && echo "✓ Server Setup"
    [[ $mateChoice == "y" ]] && echo "✓ MATE Desktop Environment"
    [[ $guiChoice == "y" ]] && echo "✓ GUI Applications"
    [[ $vmGuestChoice == "y" ]] && echo "✓ VM Guest Additions"
    [[ $hyperVGuestChoice == "y" ]] && echo "✓ Hyper-V Guest Additions"
)

Key Information:
- Main user: $username
- Python version: $(python3 --version)
- Node.js version: $(sudo -u $username bash -c 'source ~/.nvm/nvm.sh && node --version' 2>/dev/null || echo "Not installed")
- Go version: $(go version 2>/dev/null || echo "Not installed")
- Docker version: $(docker --version 2>/dev/null || echo "Not installed")

Security Status:
- Firewall: $(ufw status | grep -q "Status: active" && echo "Active" || echo "Inactive")
- Fail2ban: $(systemctl is-active fail2ban)
- Automatic updates: Enabled

Next Steps:
1. Review security configurations in /etc/ssh/sshd_config.d/99-hardened.conf
2. Test SSH connection before closing current session
3. Run 'lynis audit system' for security audit
4. Configure application-specific settings as needed

Logs:
- Setup log: ${CONFIG[LOG_FILE]}
- Backup location: ${CONFIG[BACKUP_DIR]}
EOL
    
    chown "$username:$username" "/home/$username/ubuntu-setup-summary.log"
    
    print_success "Installation summary created at: /home/$username/ubuntu-setup-summary.log"
    
    # Print detailed installation summary
    print_installation_summary
    
    # Display summary
    echo
    print_header "Setup Complete!"
    
    echo -e "${GREEN}${ROCKET} Ubuntu Ultimate Setup has been completed successfully!${NC}"
    echo
    echo -e "${CYAN}Summary:${NC}"
    cat "/home/$username/ubuntu-setup-summary.log" | grep "✓" | while read line; do
        echo -e "  ${GREEN}$line${NC}"
    done
    
    echo
    echo -e "${YELLOW}${BOLD}Important:${NC}"
    echo -e "  ${ARROW} A summary has been saved to: ${CYAN}/home/$username/ubuntu-setup-summary.log${NC}"
    echo -e "  ${ARROW} System backup created at: ${CYAN}${CONFIG[BACKUP_DIR]}${NC}"
    echo -e "  ${ARROW} Setup log available at: ${CYAN}${CONFIG[LOG_FILE]}${NC}"
    
    if [[ $serverChoice == "y" ]]; then
        echo
        echo -e "${RED}${BOLD}SSH Security Notice:${NC}"
        echo -e "  ${ARROW} SSH has been hardened - only key-based authentication is allowed"
        echo -e "  ${ARROW} Test SSH connection before closing this session!"
        echo -e "  ${ARROW} SSH user: ${CYAN}$username${NC}"
    fi
    
    if [[ $preventRebootChoice != "y" ]]; then
        echo
        echo -e "${YELLOW}${BOLD}System will reboot in 10 seconds...${NC}"
        echo -e "${YELLOW}Press Ctrl+C to cancel${NC}"
        
        for i in {10..1}; do
            echo -ne "\r${YELLOW}Rebooting in $i seconds... ${NC}"
            sleep 1
        done
        
        echo
        print_status "Rebooting system..."
        reboot
    else
        echo
        echo -e "${YELLOW}${BOLD}Please reboot the system manually to ensure all changes take effect.${NC}"
    fi
fi
