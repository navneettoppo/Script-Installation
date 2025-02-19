#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Checking if any pre inistalled 
echo "Updating and upgrading the system..."
ls /usr/bin/kubeadm
ls /usr/bin/kubectl
sudo find / -name kubeadm
sudo find / -name kubectl

sudo apt-get purge -y kubeadm kubectl kubelet kubernetes-cni kube*
sudo apt-get autoremove -y

# Update and upgrade the system
echo "Updating and upgrading the system..."
sudo apt update && sudo apt upgrade -y
sudo apt update
sudo apt install -y kubelet kubeadm kubectl --allow-change-held-packages
sudo apt-mark hold kubelet kubeadm kubectl

# Install Docker if not already installed
# Install Docker if not already installed
if command_exists docker; then
    echo "Docker is already installed: $(docker --version)"
else
    echo "Installing Docker..."
    sudo apt install -y docker.io
    if [ $? -ne 0 ]; then
        echo "Error installing Docker. Exiting."
        exit 1
    fi
    echo "Docker installed: $(docker --version)"
fi

# Add Kubernetes apt repository if not already added
if [ ! -f /etc/apt/sources.list.d/kubernetes.list ]; then
    echo "Adding Kubernetes apt repository..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
else
    echo "Kubernetes apt repository is already added."
fi

# Install Kubernetes components if not already installed
if command_exists kubelet && command_exists kubeadm && command_exists kubectl; then
    echo "Kubernetes components are already installed: kubelet $(kubelet --version), kubeadm $(kubeadm version -o short), kubectl $(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')"
else
    echo "Installing Kubernetes components..."
    sudo apt update
    sudo apt install -y kubelet kubeadm kubectl --allow-change-held-packages
    if [ $? -ne 0 ]; then
        echo "Error installing Kubernetes components. Exiting."
        exit 1
    fi
    sudo apt-mark hold kubelet kubeadm kubectl
    echo "Kubernetes components installed successfully."
fi

# Disable swap if not already disabled
if sudo swapon --show | grep -q 'swap'; then
    echo "Disabling swap..."
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    echo "Swap disabled."
else
    echo "Swap is already disabled."
fi

echo "All steps completed successfully."

# Check if the first script executed successfully
if [ $? -eq 0 ]; then
    echo "First script executed successfully. Running the next script..."
    curl -sSL https://raw.githubusercontent.com/navneettoppo/Script-Installation/refs/heads/main/kubernetes/setup-k8s.sh | bash
else
    echo "First script failed. Not running the next script."
fi