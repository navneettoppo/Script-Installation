
#!/bin/bash

# Set script name and version
SCRIPT_NAME="k8s-init"
VERSION="2.0.0"

# Enable error handling
set -eo pipefail
trap 'echo -e "\nERROR: Script failed at line $LINENO\n$BASH_COMMAND\n"' ERR
trap 'echo -e "\nScript interrupted by user\n"' INT

# Load configuration
CONFIG_FILE="k8s-config.yml"
LOAD_CONFIG() {
    if [ -f "$CONFIG_FILE" ]; then
        MASTER_IP=$(yq e '.master_ip' "$CONFIG_FILE")
        TOKEN=$(yq e '.token' "$CONFIG_FILE")
        CA_CERT_HASH=$(yq e '.ca_cert_hash' "$CONFIG_FILE")
        POD_NETWORK=$(yq e '.pod_network' "$CONFIG_FILE")
    fi
}

# Initialize master node
INIT_MASTER() {
    echo -e "\nInitializing master node..."
    
    # Check if kubeadm is installed
    if ! command -v kubeadm &> /dev/null; then
        echo -e "ERROR: kubeadm is not installed. Please install Kubernetes tools first."
        exit 1
    fi

    # Check if already initialized
    if [ -f "/etc/kubernetes/admin.conf" ]; then
        echo -e "Master node already initialized."
        return
    fi

    # Initialize cluster
    echo -e "Initializing cluster with kubeadm..."
    sudo kubeadm init --pod-network-cidr=10.244.0.0/16

    # Set up kubeconfig
    mkdir -p "$HOME/.kube"
    sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
    sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

    echo -e "Master node initialized successfully."
    echo -e "Kubernetes version: $(kubectl version --short | awk '{print $2}')"
}

# Join worker node
JOIN_WORKER() {
    echo -e "\nJoining worker node to cluster..."
    
    # Validate required parameters
    if [ -z "$MASTER_IP" ]; then
        echo -e "ERROR: Master IP not provided. Please set MASTER_IP in config or run with --master-ip"
        exit 1
    fi
    if [ -z "$TOKEN" ]; then
        echo -e "ERROR: Token not provided. Please set TOKEN in config or run with --token"
        exit 1
    fi
    if [ -z "$CA_CERT_HASH" ]; then
        echo -e "ERROR: CA cert hash not provided. Please set CA_CERT_HASH in config or run with --ca-cert-hash"
        exit 1
    fi

    # Validate master IP format
    if ! echo "$MASTER_IP" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
        echo -e "ERROR: Invalid master IP address format"
        exit 1
    fi

    # Check if already joined
    if kubeadm config view &> /dev/null; then
        echo -e "Worker node already joined to cluster."
        return
    fi

    # Join cluster
    echo -e "Joining cluster..."
    sudo kubeadm join "$MASTER_IP:6443" --token "$TOKEN" --discovery-token-ca-cert-hash "sha256:$CA_CERT_HASH"

    echo -e "Worker node joined successfully."
}

# Check cluster status
CHECK_STATUS() {
    echo -e "\nChecking cluster status..."
    
    # Check if kubectl is configured
    if [ ! -f "$HOME/.kube/config" ]; then
        echo -e "ERROR: Kubeconfig not found. Please initialize master node first."
        return
    fi

    echo -e "Cluster nodes:"
    kubectl get nodes -o wide
    echo -e "\nPods:"
    kubectl get pods --all-namespaces
}

# Deploy networking
DEPLOY_NETWORK() {
    echo -e "\nDeploying pod network..."
    
    # Check if pod network is already deployed
    if kubectl get pods -n kube-system | grep -q 'calico\|flannel'; then
        echo -e "Pod network already deployed."
        return
    fi

    case "$POD_NETWORK" in
        "flannel")
            echo -e "Deploying Flannel..."
            kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
            ;;
        "calico")
            echo -e "Deploying Calico..."
            curl -s https://docs.projectcalico.org/manifests/calico.yaml | kubectl apply -f -
            ;;
        *)
            echo -e "ERROR: Unsupported pod network: $POD_NETWORK"
            return
            ;;
    esac

    echo -e "Pod network deployed successfully."
}

# Reset cluster
RESET_CLUSTER() {
    echo -e "\nResetting cluster..."
    
    # Check if cluster is initialized
    if [ ! -f "/etc/kubernetes/admin.conf" ]; then
        echo -e "Cluster not initialized."
        return
    fi

    # Backup current config
    mkdir -p ~/k8s-backup
    cp -i "$HOME/.kube/config" ~/k8s-backup/

    # Reset cluster
    sudo kubeadm reset --force
    rm -rf "$HOME/.kube/config"

    echo -e "Cluster reset successfully."
}

# Show help
SHOW_HELP() {
    echo -e "Usage: $SCRIPT_NAME [options]"
    echo -e ""
    echo -e "Options:"
    echo -e "  -m, --master-ip      Master node IP address"
    echo -e "  -t, --token          Join token for worker nodes"
    echo -e "  -c, --ca-cert-hash   CA certificate hash"
    echo -e "  -n, --pod-network    Pod network to deploy (flannel/calico)"
    echo -e "  -f, --config-file    Path to configuration file"
    echo -e "  -h, --help           Show this help message"
    echo -e "  -v, --version       Show script version"
}

# Main execution
main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --master-ip|--m)
                MASTER_IP="$2"
                shift 2
                ;;
            --token|--t)
                TOKEN="$2"
                shift 2
                ;;
            --ca-cert-hash|--c)
                CA_CERT_HASH="$2"
                shift 2
                ;;
            --pod-network|--n)
                POD_NETWORK="$2"
                shift 2
                ;;
            --config-file|--f)
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
    if [ -z "$MASTER_IP" ] || [ -z "$TOKEN" ] || [ -z "$CA_CERT_HASH" ]; then
        LOAD_CONFIG
    fi

    # Show menu
    while true; do
        echo -e "\n$SCRIPT_NAME v$VERSION"
        echo -e "-------------------"
        echo -e "1. Initialize Master Node"
        echo -e "2. Join Worker Node"
        echo -e "3. Check Cluster Status"
        echo -e "4. Deploy Networking"
        echo -e "5. Reset Cluster"
        echo -e "6. Show Config"
        echo -e "7. Exit"
        read -p "Choose an option: " CHOICE

        case "$CHOICE" in
            1)
                INIT_MASTER
                ;;
            2)
                JOIN_WORKER
                ;;
            3)
                CHECK_STATUS
                ;;
            4)
                DEPLOY_NETWORK
                ;;
            5)
                RESET_CLUSTER
                ;;
            6)
                echo -e "\nCurrent Configuration:"
                echo -e "Master IP: $MASTER_IP"
                echo -e "Token: $TOKEN"
                echo -e "CA Cert Hash: $CA_CERT_HASH"
                echo -e "Pod Network: $POD_NETWORK"
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

# Start main function
main "$@"

# Example usage:
# Initialize master node:
# sudo ./k8s-init.sh --master-ip 192.168.1.100
#
# Join worker node:
# sudo ./k8s-init.sh --master-ip 192.168.1.100 --token abcdef.1234567890abcdef --ca-cert-hash sha256:1234567890abcdef
#
# Use configuration file:
# ./k8s-init.sh --config-file k8s-config.yml
