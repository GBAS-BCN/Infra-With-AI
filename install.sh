#!/usr/bin/bash
#
#   Infra-With-AI Automated Installer Script
#   Based on CasaOS-style formatting
#
#   Usage:
#   	$ wget -qO- https://your-domain.com/install.sh | sudo bash
#
#   This script strictly assumes a fresh Debian/Ubuntu environment.
#   It will install Docker, Nix, Devbox, GH CLI, kubectl, and setup the environment.
#

clear
echo -e "\e[0m\c"

# shellcheck disable=SC2016
echo '
 /$$$$$$            /$$$$$$                           /$$      /$$ /$$   /$$     /$$                /$$$$$$  /$$$$$$
|_  $$_/           /$$__  $$                         | $$  /$ | $$|__/  | $$    | $$               /$$__  $$|_  $$_/
  | $$   /$$$$$$$ | $$  \__//$$$$$$  /$$$$$$         | $$ /$$$| $$ /$$ /$$$$$$  | $$$$$$$         | $$  \ $$  | $$  
  | $$  | $$__  $$| $$$$   /$$__  $$|____  $$ /$$$$$$| $$/$$ $$ $$| $$|_  $$_/  | $$__  $$ /$$$$$$| $$$$$$$$  | $$  
  | $$  | $$  \ $$| $$_/  | $$  \__/ /$$$$$$$|______/| $$$$_  $$$$| $$  | $$    | $$  \ $$|______/| $$__  $$  | $$  
  | $$  | $$  | $$| $$    | $$      /$$__  $$        | $$$/ \  $$$| $$  | $$ /$$| $$  | $$        | $$  | $$  | $$  
 /$$$$$$| $$  | $$| $$    | $$     |  $$$$$$$        | $$/   \  $$| $$  |  $$$$/| $$  | $$        | $$  | $$ /$$$$$$
|______/|__/  |__/|__/    |__/      \_______/        |__/     \__/|__/   \___/  |__/  |__/        |__/  |__/|______/
                                                                                                                   
                  --- Automated Environment Setup ---
'

export PATH=/usr/sbin:/usr/local/bin:/usr/bin:$PATH
export DEBIAN_FRONTEND=noninteractive

set -e

###############################################################################
# GLOBALS & PRE-FLIGHT                                                        #
###############################################################################

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (or with sudo)." 
   exit 1
fi

# Determine the actual user (so we don't clone the repo as root)
REAL_USER=${SUDO_USER:-$(who -m | awk '{print $1}')}
if [[ -z "$REAL_USER" || "$REAL_USER" == "root" ]]; then
    echo "Please run this script using sudo from a standard user account."
    echo "Example: sudo ./install.sh"
    exit 1
fi

REAL_HOME=$(eval echo "~$REAL_USER")
REPO_DIR="$REAL_HOME/infra-with-ai"

# shellcheck source=/dev/null
source /etc/os-release

# COLORS
readonly COLOUR_RESET='\e[0m'
readonly aCOLOUR=(
    '\e[38;5;154m' # green      | Lines, bullets and separators
    '\e[1m'        # Bold white | Main descriptions
    '\e[90m'       # Grey       | Credits
    '\e[91m'       # Red        | Update notifications Alert
    '\e[33m'       # Yellow     | Emphasis
)

readonly GREEN_LINE=" ${aCOLOUR[0]}─────────────────────────────────────────────────────$COLOUR_RESET"
readonly GREEN_BULLET=" ${aCOLOUR[0]}-$COLOUR_RESET"
readonly GREEN_SEPARATOR="${aCOLOUR[0]}:$COLOUR_RESET"

trap 'onCtrlC' INT
onCtrlC() {
    echo -e "${COLOUR_RESET}"
    echo "Installation cancelled by user."
    exit 1
}

###############################################################################
# HELPERS                                                                     #
###############################################################################

Show() {
    # 0:OK   1:FAILED  2:INFO  3:NOTICE
    if (($1 == 0)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[0]}  OK  $COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
    elif (($1 == 1)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[3]}FAILED$COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
        exit 1
    elif (($1 == 2)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[0]} INFO $COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
    elif (($1 == 3)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[4]}NOTICE$COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
    fi
}

GreyStart() {
    echo -e "${aCOLOUR[2]}\c"
}

ColorReset() {
    echo -e "$COLOUR_RESET\c"
}

###############################################################################
# FUNCTIONS                                                                   #
###############################################################################

Check_OS() {
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        Show 1 "This script strictly assumes a Debian or Ubuntu environment. Detected: $ID"
    fi
    Show 0 "OS check passed: $PRETTY_NAME"
}

Update_Package_Resource() {
    Show 2 "Updating apt package manager..."
    GreyStart
    apt-get update -qq
    ColorReset
    Show 0 "Apt update complete."
}

Install_Base_Depends() {
    Show 2 "Installing base dependencies (git, curl, wget, jq, unzip, apache2-utils)..."
    GreyStart
    apt-get install -y -qq git curl wget jq unzip ca-certificates gnupg lsb-release xz-utils apache2-utils
    ColorReset
    Show 0 "Base dependencies installed."
}

Install_Docker() {
    if [[ -x "$(command -v docker)" ]]; then
        Show 0 "Docker is already installed."
    else
        Show 2 "Installing Docker..."
        GreyStart
        curl -fsSL https://get.docker.com | bash
        ColorReset
        Show 0 "Docker installed successfully."
    fi

    # Ensure the real user can run Docker
    usermod -aG docker "$REAL_USER"
    Show 0 "Added user $REAL_USER to the docker group."
    
    # Ensure Docker is running
    systemctl enable docker --now
}

Install_GH_CLI() {
    if [[ -x "$(command -v gh)" ]]; then
        Show 0 "GitHub CLI is already installed."
    else
        Show 2 "Installing GitHub CLI..."
        GreyStart
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        apt-get update -qq
        apt-get install -y -qq gh
        ColorReset
        Show 0 "GitHub CLI installed."
    fi
}

Install_Kubectl() {
    if [[ -x "$(command -v kubectl)" ]]; then
        Show 0 "kubectl is already installed."
    else
        Show 2 "Installing kubectl..."
        GreyStart
        local ARCH
        ARCH=$(uname -m)
        if [[ "$ARCH" == "x86_64" ]]; then ARCH="amd64"; fi
        if [[ "$ARCH" == "aarch64" ]]; then ARCH="arm64"; fi
        
        local KUBECTL_VERSION
        KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
        
        curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
        chmod 755 /usr/local/bin/kubectl
        
        ColorReset
        Show 0 "kubectl installed successfully."
    fi
}

Install_Devbox() {
    Show 2 "Verifying Nix package manager..."
    GreyStart
    
    # Robust check to see if Nix is actually fully installed already
    if [[ -d "/nix/store" ]] && [[ -n "$(ls -A /nix/store 2>/dev/null)" ]]; then
        echo "Nix is already installed, skipping..."
    else
        # Pre-clean any leftover backup files from previously failed/aborted installations
        rm -f /etc/bash.bashrc.backup-before-nix /etc/bashrc.backup-before-nix /etc/profile.d/nix.sh.backup-before-nix /etc/zshrc.backup-before-nix 2>/dev/null || true
        
        # Install Nix Daemon
        curl -L https://nixos.org/nix/install | sh -s -- --daemon --yes
    fi
    
    ColorReset
    Show 0 "Nix setup verified."

    Show 2 "Installing Devbox..."
    GreyStart
    
    # Force remove any corrupted/mis-permissioned devbox installs from previous runs
    rm -rf /usr/local/bin/devbox
    
    # Devbox installs system-wide to /usr/local/bin, safely executed as root without a password prompt
    curl -fsSL https://get.jetpack.io/devbox | FORCE=1 bash
    
    # Ensure the binary is strictly owned by root but executable by all users
    chown root:root /usr/local/bin/devbox
    chmod 755 /usr/local/bin/devbox
    
    ColorReset
    Show 0 "Devbox installed successfully."
}

Install_OpenCode() {
    Show 2 "Installing OpenCode Terminal..."
    GreyStart
    # We run this as the standard user so it correctly configures their ~/.bashrc or ~/.local/bin paths
    sudo -i -u "$REAL_USER" bash -c "curl -fsSL https://opencode.ai/install | bash"
    ColorReset
    Show 0 "OpenCode installed successfully."
}

Clone_And_Setup_Repo() {
    Show 2 "Setting up infra-with-ai repository..."

    if [[ -d "$REPO_DIR" ]]; then
        Show 3 "Directory $REPO_DIR already exists. Resetting to main branch and pulling latest changes..."
        # If the script previously completed, we might be on the 'agents' branch. We must switch back to 'main' for setup!
        sudo -i -u "$REAL_USER" bash -c "cd $REPO_DIR && git reset --hard HEAD && git switch main && git pull"
    else
        Show 2 "Cloning infra-with-ai..."
        sudo -i -u "$REAL_USER" bash -c "git clone https://github.com/vfarcic/infra-with-ai $REPO_DIR"
    fi

    # FAILSAFE: Ensure the standard user truly owns the repo and all Devbox cache/config folders.
    chown -R "$REAL_USER:$REAL_USER" "$REPO_DIR"
    chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.local/share/devbox" 2>/dev/null || true
    chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.config/devbox" 2>/dev/null || true
    chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.cache/devbox" 2>/dev/null || true

    Show 0 "Repository prepared."

    Show 2 "Making setup script executable..."
    sudo -i -u "$REAL_USER" bash -c "cd $REPO_DIR && chmod +x dot.nu"

    Show 2 "Patching script timeouts and WSL browser quirks..."
    # 1. Update any existing explicit timeouts (e.g. --timeout 90s or --timeout=90s) to 15 minutes
    sudo -i -u "$REAL_USER" bash -c "cd $REPO_DIR && sed -i -E 's/--timeout[= ]*[0-9]+[a-zA-Z]+/--timeout=15m/g' dot.nu"
    # 2. Inject a 15-minute timeout into ALL kubectl wait commands
    sudo -i -u "$REAL_USER" bash -c "cd $REPO_DIR && sed -i 's/kubectl wait /kubectl wait --timeout=15m /g' dot.nu"
    # 3. Prevent WSL from crashing when trying to auto-open browsers. Replace 'start' with 'print'.
    sudo -i -u "$REAL_USER" bash -c "cd $REPO_DIR && find . -name '*.nu' -type f -exec sed -i 's/start \$\"https/print \$\"Please manually open this link in your browser to proceed:\\nhttps/g' {} +"

    Show 2 "Ensuring a clean slate for the 'dot' Kubernetes cluster..."
    # Force remove any existing kind nodes for the 'dot' cluster directly via Docker.
    # This is much faster and more reliable than passing it through devbox/nix.
    docker ps -a --filter "name=^dot-" --format "{{.ID}}" | xargs -r docker rm -f >/dev/null 2>&1

    # Brief pause to let Docker register the removal
    sleep 2

    Show 2 "Executing Devbox environment setup via Nushell..."
    # We use devbox run to execute commands *inside* the configured nix environment.
    GreyStart
    # Re-bind standard input explicitly inside the unprivileged subshell so the 'Enter' key is forwarded to gcloud.
    sudo -i -u "$REAL_USER" bash -c "cd $REPO_DIR && /usr/local/bin/devbox run -- nu ./dot.nu setup < /dev/tty"
    
    # Explicitly export the Kubernetes configuration so the user's default environment can instantly connect
    sudo -i -u "$REAL_USER" bash -c "cd $REPO_DIR && /usr/local/bin/devbox run -- kind export kubeconfig --name dot >/dev/null 2>&1"
    
    ColorReset
    Show 0 "Infrastructure setup completed."

    Show 2 "Switching to 'agents' git branch..."
    # Forcefully reset the script patches (timeouts/browsers) so git allows us to cleanly switch branches
    sudo -i -u "$REAL_USER" bash -c "cd $REPO_DIR && git reset --hard HEAD >/dev/null 2>&1 && git switch agents"
    Show 0 "Git branch switched successfully."
}

Welcome_Banner() {
    echo -e "${GREEN_LINE}${aCOLOUR[1]}"
    echo -e " Infrastructure with AI is ready!${COLOUR_RESET}"
    echo -e "${GREEN_LINE}"
    echo -e " The repository is located at:"
    echo -e " ${aCOLOUR[3]}$REPO_DIR${COLOUR_RESET}"
    echo -e ""
    echo -e " ${aCOLOUR[4]}IMPORTANT NEXT STEPS:${COLOUR_RESET}"
    echo -e " 1. Log into your new environment as '$REAL_USER'."
    echo -e "    Since we added you to the docker group, you may need to log out and log back in."
    echo -e " 2. Navigate to the folder: ${aCOLOUR[2]}cd ~/infra-with-ai${COLOUR_RESET}"
    echo -e " 3. Open Devbox shell:      ${aCOLOUR[2]}devbox shell${COLOUR_RESET}"
    echo -e " 4. Load Env vars:          ${aCOLOUR[2]}source .env${COLOUR_RESET}"
    echo -e " 5. Open the terminal app:  ${aCOLOUR[2]}opencode${COLOUR_RESET}"
    echo -e ""
    echo -e " ${aCOLOUR[1]}To Destroy the Environment later, run:${COLOUR_RESET}"
    echo -e "   cd ~/infra-with-ai"
    echo -e "   git switch main"
    echo -e "   gh repo delete infra-with-ai-gitops"
    echo -e "   devbox run -- nu ./dot.nu destroy"
    echo -e "${GREEN_LINE}"
}

###############################################################################
# MAIN EXECUTION                                                              #
###############################################################################

Check_OS
Update_Package_Resource
Install_Base_Depends
Install_Docker
Install_GH_CLI
Install_Kubectl
Install_Devbox
Clone_And_Setup_Repo
Install_OpenCode
Welcome_Banner

exit 0