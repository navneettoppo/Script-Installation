#!/bin/bash
# Set script name and version
SCRIPT_NAME="k8s-install"
VERSION="2.1.0"

# Enable error handling with colors
set -eo pipefail
trap 'echo -e "\nERROR: Script failed at line $LINENO\n$BASH_COMMAND\n$" >&2' ERR
trap 'echo -e "\nScript interrupted by user\n"' INT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load configuration
CONFIG_FILE="k8s-install-config.yml"
K8S_VERSION="1.28.0"
DOCKER_REPO="https://download.docker.com/linux/ubuntu/gpg"
POD_NETWORK="flannel"
DISABLE_SWAP="true"

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Show help
SHOW_HELP() {
    echo -e "${BLUE}Usage:$NC $SCRIPT_NAME [options]"
    echo -e ""
    echo -e "${BLUE}Options:$NC"
    echo -e "  --config-file    Path to configuration file"
    echo -e "  --help           Show this help message"
    echo -e "  --version       Show script version"
    echo -e ""
    echo -e "${BLUE}Examples:$NC"
    echo -e "  $SCRIPT_NAME --config-file ./your-config.yml"
    echo -e "  $SCRIPT_NAME --help"
    echo -e "  $SCRIPT_NAME --version"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: This script must be run as root${NC}" >&2
    SHOW_HELP
    exit 1
fi

# Load configuration
LOAD_CONFIG() {
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}Loading configuration from $CONFIG_FILE...${NC}"
        if ! command_exists yq; then
            echo -e "${RED}ERROR: yq command not found. Please install it first.${NC}" >&2
            exit 1
        fi
        K8S_VERSION=$(yq e '.kubernetes.version' "$CONFIG_FILE")
        DOCKER_REPO=$(yq e '.docker.repository' "$CONFIG_FILE")
        POD_NETWORK=$(yq e '.network.pod_network' "$CONFIG_FILE")
        DISABLE_SWAP=$(yq e '.system.swap.disabled' "$CONFIG_FILE")
    else
        echo -e "${YELLOW}No configuration file found. Using defaults:${NC}"
        echo -e "Kubernetes Version: $K8S_VERSION"
        echo -e "Docker Repository: $DOCKER_REPO"
        echo -e "Pod Network: $POD_NETWORK"
        echo -e "Swap Disabled: $DISABLE_SWAP"
    fi
}

# Uninstall old Kubernetes components
UNINSTALL_OLD() {
    echo -e "${BLUE}\nUninstalling old Kubernetes components...${NC}"
    sudo apt-get purge -y kubeadm kubectl kubelet kubernetes-cni kube*
    sudo apt-get autoremove -y
    echo -e "${GREEN}Old Kubernetes components uninstalled.${NC}"
}

# Update and upgrade system
UPDATE_SYSTEM() {
    echo -e "${BLUE}\nUpdating and upgrading the system...${NC}"
    sudo apt update && sudo apt upgrade -y
    sudo apt-get update
    echo -e "${GREEN}System updated successfully.${NC}"
}

# Install Docker
INSTALL_DOCKER() {
    echo -e "${BLUE}\nInstalling Docker...${NC}"
    
    if command_exists docker; then
        echo -e "${YELLOW}Docker is already installed: $(docker --version)${NC}"
        return
    fi

    echo -e "${BLUE}Adding Docker repository...${NC}"
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL "$DOCKER_REPO" -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo -e "${BLUE}Updating package lists...${NC}"
    sudo apt-get update

    echo -e "${BLUE}Installing Docker components...${NC}"
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Failed to install Docker components${NC}" >&2
        exit 1
    fi

    echo -e "${BLUE}Starting Docker service...${NC}"
    sudo systemctl start docker
    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Failed to start Docker service${NC}" >&2
        exit 1
    fi

    echo -e "${GREEN}Docker installed successfully: $(docker --version)${NC}"
}

# Install Kubernetes components
INSTALL_K8S() {
    echo -e "${BLUE}\nInstalling Kubernetes components...${NC}"
    
    if command_exists kubelet && command_exists kubeadm && command_exists kubectl; then
        echo -e "${YELLOW}Kubernetes components are already installed:${NC}"
        echo -e "kubelet: $(kubelet --version)"
        echo -e "kubeadm: $(kubeadm version -o short)"
        echo -e "kubectl: $(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')"
        return
    fi

    echo -e "${BLUE}Adding Kubernetes repository...${NC}"
    sudo mkdir -p /etc/apt/keyrings
    sudo curl -fsSL "https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION/deb/Release.key" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo -e "${BLUE}Updating package lists...${NC}"
    sudo apt-get update

    echo -e "${BLUE}Installing Kubernetes components...${NC}"
    sudo apt-get install -y kubelet kubeadm kubectl --allow-change-held-packages
    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Failed to install Kubernetes components${NC}" >&2
        exit 1
    fi

    sudo apt-mark hold kubelet kubeadm kubectl
    echo -e "${GREEN}Kubernetes components installed successfully.${NC}"
}

# Disable swap
DISABLE_SWAP() {
    echo -e "${BLUE}\nChecking swap status...${NC}"
    
    if sudo swapon --show | grep -q 'swap'; then
        echo -e "${BLUE}Disabling swap...${NC}"
        sudo swapoff -a
        sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
        echo -e "${GREEN}Swap disabled.${NC}"
    else
        echo -e "${YELLOW}Swap is already disabled.${NC}"
    fi
}

# Show configuration
SHOW_CONFIG() {
    echo -e "${BLUE}\nCurrent Configuration:${NC}"
    echo -e "Kubernetes Version: $K8S_VERSION"
    echo -e "Docker Repository: $DOCKER_REPO"
    echo -e "Pod Network: $POD_NETWORK"
    echo -e "Swap Status: $DISABLE_SWAP"
}

# Main execution
main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --config-file)
                CONFIG_FILE="$2"
                shift 2
                LOAD_CONFIG
                ;;
            --help|--h)
                SHOW_HELP
                exit 0
                ;;
            --version|--v)
                echo "$SCRIPT_NAME version $VERSION"
                exit 0
                ;;
            *)
                SHOW_HELP
                exit 1
                ;;
        esac
    done

    # Load configuration if not already loaded
    LOAD_CONFIG

    # Show menu
    while true; do
        echo -e "\n${BLUE}$SCRIPT_NAME v$VERSION${NC}"
        echo -e "---------------------"
        echo -e "${BLUE}1.${NC} Uninstall Old Components"
        echo -e "${BLUE}2.${NC} Update System"
        echo -e "${BLUE}3.${NC} Install Docker"
        echo -e "${BLUE}4.${NC} Install Kubernetes"
        echo -e "${BLUE}5.${NC} Disable Swap"
        echo -e "${BLUE}6.${NC} Show Configuration"
        echo -e "${BLUE}7.${NC} Exit"
        read -p "Choose an option: " CHOICE

        case "$CHOICE" in
            1)
                UNINSTALL_OLD
                ;;
            2)
                UPDATE_SYSTEM
                ;;
            3)
                INSTALL_DOCKER
                ;;
            4)
                INSTALL_K8S
                ;;
            5)
                DISABLE_SWAP
                ;;
            6)
                SHOW_CONFIG
                ;;
            7)
                echo -e "${BLUE}Exiting...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                ;;
        esac
    done
}

# Start main function
main "$@"