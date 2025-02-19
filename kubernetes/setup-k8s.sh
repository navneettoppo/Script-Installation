#!/bin/bash

read -p "Is this the master node? (yes/no): " is_master

if [ "$is_master" == "yes" ]; then
    # Check if the master node is already initialized
    if [ -f /etc/kubernetes/admin.conf ]; then
        echo "Master node is already initialized."
    else
        # Initialize the master node
        sudo kubeadm init --pod-network-cidr=10.244.0.0/16

        # Set up kubeconfig for the master node
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config

        echo "Master node initialized successfully. Please deploy a pod network add-on."
        echo "Run the following command to deploy Flannel:"
        echo "kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"
    fi
else
    read -p "Enter the master node IP: " master_ip
    read -p "Enter the token: " token
    read -p "Enter the discovery token CA cert hash: " ca_cert_hash

    # Check if the worker node is already joined
    if sudo kubeadm config view | grep -q "apiServer"; then
        echo "Worker node is already joined to the cluster."
    else
        # Join the worker node to the cluster
        sudo kubeadm join $master_ip:6443 --token $token --discovery-token-ca-cert-hash sha256:$ca_cert_hash

        echo "Worker node joined to the cluster successfully."
    fi
fi