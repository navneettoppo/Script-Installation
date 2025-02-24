# Script-Installation

``` curl -sSL https://raw.githubusercontent.com/navneettoppo/Script-Installation/refs/heads/main/kubernetes/install-k8s.sh | bash 
    curl -sSL https://raw.githubusercontent.com/navneettoppo/Script-Installation/refs/heads/main/kubernetes/setup-k8s.sh | bash
```


# Kubernetes Installation and Setup Scripts

A collection of shell scripts for automating Kubernetes cluster installation and setup. These scripts provide a streamlined, user-friendly experience for deploying Kubernetes environments.

## Table of Contents
- [Description](#description)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Use Cases](#use-cases)
- [Contact](#contact)

# Kubernetes Installation and Setup Scripts 🚀

![GitHub](https://img.shields.io/github/license/navneettoppo/Script-Installation?style=flat-square)
![Kubernetes Version](https://img.shields.io/badge/kubernetes-1.28%2B-blue?style=flat-square)
![Shell Script](https://img.shields.io/badge/shell_script-%3E%3Dbash-green?style=flat-square)

A collection of **production-grade** shell scripts for automating Kubernetes cluster installation and setup. Designed for both developers and sysadmins, these scripts provide a streamlined experience with robust error handling and configuration management.

```bash
# One-liner installation (Master Node)
curl -sSL https://raw.githubusercontent.com/navneettoppo/Script-Installation/refs/heads/main/kubernetes/Install-K8s-2.sh | bash -s -- --role master

# One-liner installation (Worker Node)
curl -sSL https://raw.githubusercontent.com/navneettoppo/Script-Installation/refs/heads/main/kubernetes/Setup-K8s-2.sh | bash -s -- --role worker
```

## Description
This repository contains two main scripts:
- `Install-K8s.sh`: Handles the installation of Docker and Kubernetes components.
- `Setup-K8s.sh`: Configures the Kubernetes cluster and its components.

These scripts are designed to automate the entire Kubernetes setup process, making it easier for developers and system administrators to deploy Kubernetes environments.

## Features
- **Docker Installation**: Automatically installs Docker and its dependencies.
- **Kubernetes Components**: Installs and configures Kubernetes components (kubelet, kubeadm, kubectl).
- **Swap Management**: Disables swap if enabled.
- **Configuration File Support**: Uses YAML configuration files for customizable setups.
- **Error Handling**: Includes comprehensive error handling and validation.
- **Menu-Driven Interface**: Provides an interactive menu for easy operation.

## Requirements
- **Operating System**: Ubuntu/Debian-based systems
- **Docker**: Required for container orchestration
- **Kubernetes**: Version 1.28+
- **Root Access**: Scripts require sudo privileges

## Installation
1. Clone the repository:
```bash
  git clone https://github.com/yourusername/kubernetes-setup.git
  cd kubernetes-setup
  Make the scripts executable:
  chmod +x Install-K8s.sh Setup-K8s.sh
  Usage
  Running Install-K8s.sh
  sudo ./Install-K8s.sh
  Running Setup-K8s.sh
  sudo ./Setup-K8s.sh
```

# Using Configuration File
Create a configuration file:
``` vi config.yml

kubernetes:
  version: "1.28"
docker:
  repository: "https://download.docker.com/linux/ubuntu/gpg"
network:
  pod_network: "flannel"
system:
  swap:
    disabled: true
```

Run the script with the configuration file:
```sudo ./Install-K8s.sh --config-file config.yml ```

Configuration
The scripts use a YAML configuration file for customizable settings:

kubernetes.version: Kubernetes version to install
docker.repository: Docker repository URL
network.pod_network: Pod network type (e.g., flannel)
system.swap.disabled: Enable/disable swap
Use Cases
Development Environment: Quickly spin up a Kubernetes cluster for development and testing.
Production Cluster: Use the scripts to automate Kubernetes deployment in production environments.
Education: Ideal for learning Kubernetes installation and configuration.
CI/CD Pipelines: Integrate the scripts into CI/CD workflows for automated cluster setup.
Contact
For questions, suggestions, or issues, please:

Open an issue on GitHub
Contact the maintainer at your.email@domain.com
License
[Your License Here]


This README.md file provides comprehensive documentation for your Kubernetes installation and setup scripts. It includes usage instructions, configuration details, and common use cases to help users understand and utilize the scripts effectively.
