#!/bin/bash

set -e

echo "🚀 Starting full DevOps pipeline..."

# Step 1: Get Terraform output
cd ../terraform

IP=$(terraform output -raw instance_public_ip)

echo "✅ Terraform IP fetched: $IP"

# Step 2: Move back to Ansible folder
cd ../ansible

# Step 3: Generate inventory file
echo "[web]" > inventory
echo "$IP ansible_user=ubuntu ansible_ssh_private_key_file=/home/jahnavi/keys/devops-key.pem" >> inventory

echo "✅ Inventory generated successfully"

# Step 4: Run Ansible playbook
echo "🚀 Running Ansible deployment..."
ansible-playbook -i inventory deploy.yml

echo "🎉 Deployment completed successfully!"
echo "🌐 Application URL: http://$IP:5000"