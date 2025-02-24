#!/bin/bash

# Set script name and version
SCRIPT_NAME="k8s-install"
VERSION="2.0.0"

# Enable error handling
set -eo pipefail
trap 'echo -e "\nERROR: Script failed at line $LINENO\n$BASH_COMMAND\n$" ERR
trap 'echo -e "\nScript interrupted by user\n"' INT

# Load configuration
CONFIG_FILE="k8s-install-config.yml"
LOAD_CONFIG() {
    if [ -f "$CONFIG_FILE" ]; then
        K8S_VERSION=$(yq e '.kubernetes.version' "$CONFIG_FILE")
        DOCKER_REPO=$(yq e '.docker.repository' "$CONFIG_FILE")
        POD_NETWORK=$(yq e '.network.pod_network' "$CONFIG_FILE")
        DISABLE_SWAP=$(yq e '.system.swap.disabled' "$CONFIG_FILE")
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Uninstall old Kubernetes components
UNINSTALL_OLD() {
    echo -e "\nUninstalling old Kubernetes components..."
    sudo apt-get purge -y kubeadm kubectl kubelet kubernetes-cni kube*
    sudo apt-get autoremove -y
    echo -e "Old Kubernetes components uninstalled."
}

# Update and upgrade system
UPDATE_SYSTEM() {
    echo -e "\nUpdating and upgrading the system..."
    sudo apt update && sudo apt upgrade -y
    sudo apt update
    echo -e "System updated successfully."
}

# Install Docker
INSTALL_DOCKER() {
    echo -e "\nInstalling Docker..."
    
    if command_exists docker; then
        echo -e "Docker is already installed: $(docker --version)"
        return
    fi

    echo -e "Adding Docker repository..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL "$DOCKER_REPO" -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo -e "Updating package lists..."
    sudo apt-get update

    echo -e "Installing Docker components..."
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    if [ $? -ne 0 ]; then
        echo -e "ERROR: Failed to install Docker components"
        exit 1
    fi

    echo -e "Starting Docker service..."
    sudo systemctl start docker
    if [ $? -ne 0 ]; then
        echo -e "ERROR: Failed to start Docker service"
        exit 1
    fi

    echo -e "Docker installed successfully: $(docker --version)"
}

# Install Kubernetes components
INSTALL_K8S() {
    echo -e "\nInstalling Kubernetes components..."
    
    if command_exists kubelet && command_exists kubeadm && command_exists kubectl; then
        echo -e "Kubernetes components are already installed:"
        echo -e "kubelet: $(kubelet --version)"
        echo -e "kubeadm: $(kubeadm version -o short)"
        echo -e "kubectl: $(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')"
        return
    fi

    echo -e "Adding Kubernetes repository..."
    sudo mkdir -p /etc/apt/keyrings
    sudo curl -fsSL "https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION/deb/Release.key" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo -e "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

    echo -e "Updating package lists..."
    sudo apt-get update

    echo -e "Installing Kubernetes components..."
    sudo apt-get install -y kubelet kubeadm kubectl --allow-change-held-packages
    if [ $? -ne 0 ]; then
        echo -e "ERROR: Failed to install Kubernetes components"
        exit 1
    fi

    sudo apt-mark hold kubelet kubeadm kubectl
    echo -e "Kubernetes components installed successfully."
}

# Disable swap
DISABLE_SWAP() {
    echo -e "\nChecking swap status..."
    
    if sudo swapon --show | grep -q 'swap'; then
        echo -e "Disabling swap..."
        sudo swapoff -a
        sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
        echo -e "Swap disabled."
    else
        echo -e "Swap is already disabled."
    fi
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
        echo -e "\n$SCRIPT_NAME v$VERSION"
        echo -e "---------------------"
        echo -e "1. Uninstall Old Components"
        echo -e "2. Update System"
        echo -e "3. Install Docker"
        echo -e "4. Install Kubernetes"
        echo -e "5. Disable Swap"
        echo -e "6. Show Configuration"
        echo -e "7. Exit"
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
                echo -e "\nCurrent Configuration:"
                echo -e "Kubernetes Version: $K8S_VERSION"
                echo -e "Docker Repository: $DOCKER_REPO"
                echo -e "Pod Network: $POD_NETWORK"
                echo -e "Swap Status: ${DISABLE_SWAP:-true}"
                ;;
            7)
                echo -e "Exiting..."
                exit 0
                ;;
            *)
                echo -e "Invalid choice. Please try again."
                ;;
        esac
    done
}

# Show help
SHOW_HELP() {
    echo -e "Usage: $SCRIPT_NAME [options]"
    echo -e ""
    echo -e "Options:"
    echo -e "  --config-file    Path to configuration file"
    echo -e "  --help           Show this help message"
    echo -e "  --version       Show script version"
}

# Start main function
main "$@"

# Example configuration file content:
# vi $CONFIG_FILE
# kubernetes:
#   version: "1.28"
# docker:
#   repository: "https://download.docker.com/linux/ubuntu/gpg"
# network:
#   pod_network: "flannel"
# system:
#   swap:
#     disabled: true