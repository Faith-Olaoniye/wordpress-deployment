#!/bin/bash

# ===========================================
# provision.sh
# Sets up an EC2 Ubuntu server to run the WordPress + MySQL Docker application
# ===========================================

# ---- Step 1: Update system packages ----
# Update first to install the latest and most secure versions of everything

echo "Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

# ---- Step 2: Install Docker ----
# Checking if Docker is already installed before trying to install it again. 

if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."

    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) \
      signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io

    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker ubuntu

    echo "Docker installed successfully."
else
    echo "Docker is already installed. Skipping."
fi

# ---- Step 3: Install Docker Compose ----
# Docker Compose lets us run multiple containers from a single docker-compose.yml file

if ! command -v docker compose &> /dev/null; then
    echo "Installing Docker Compose..."

    sudo apt-get install -y docker-compose-plugin

    echo "Docker Compose installed successfully."
else
    echo "Docker Compose is already installed. Skipping."
fi

# ---- Step 4: Install AWS CLI ----
# The AWS CLI is needed by backup.sh to upload database backups to S3

if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."

    sudo apt-get install -y unzip
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
        -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws/

    echo "AWS CLI installed successfully."
else
    echo "AWS CLI is already installed. Skipping."
fi

# ---- Step 5: Create the MySQL data directory ----
# This is the folder where the EBS volume will be mounted. 
# MySQL data will be stored here so it persists even if the container is restarted.

echo "Creating MySQL data directory..."
sudo mkdir -p /mnt/mysql-data

# ---- Step 6: Mount the EBS volume ----
# Checking if EBS Volume is already mounted before mounting.
# Mounting twice causes errors. The EBS volume should appear as /dev/nvme1n1 after being attached in AWS.

if ! mountpoint -q /mnt/mysql-data; then
    echo "Mounting EBS volume to /mnt/mysql-data..."
    sudo mount /dev/nvme1n1 /mnt/mysql-data
    echo "EBS volume mounted successfully."
else
    echo "EBS volume is already mounted. Skipping."
fi

# ---- Step 7: Make the mount permanent ----
# Without this, the EBS volume unmounts every time the server restarts. Adding it to /etc/fstab makes
# Ubuntu re-mount it automatically on every boot.

if ! grep -q "/mnt/mysql-data" /etc/fstab; then
    echo "Adding EBS mount to /etc/fstab for persistence..."
    echo "/dev/nvme1n1 /mnt/mysql-data ext4 defaults,nofail 0 2" | \
        sudo tee -a /etc/fstab
    echo "Added to /etc/fstab."
else
    echo "/etc/fstab already configured. Skipping."
fi

# ---- Step 8: Set permissions on the data directory ----
# Docker runs MySQL as a specific user inside the container.
# Giving full ownership to ubuntu and open permissions so Docker can read and write freely.

echo "Setting permissions on /mnt/mysql-data..."
sudo chown -R ubuntu:ubuntu /mnt/mysql-data
sudo chmod 755 /mnt/mysql-data

echo "Permissions set."


# ---- All done! ----
echo ""
echo "============================================"
echo " Server provisioning complete!"
echo " You can now run: docker compose up -d"
echo "============================================"