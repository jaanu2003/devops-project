#!/bin/bash

set -e

cd ../terraform
terraform output -raw instance_public_ip > /tmp/ip.txt
IP=$(cat /tmp/ip.txt)

cd ../ansible

echo "[web]" > inventory
echo "$IP ansible_user=ubuntu ansible_ssh_private_key_file=/home/jahnavi/keys/devops-key.pem" >> inventory

echo "Inventory generated: $IP"

ansible-playbook -i inventory deploy.yml