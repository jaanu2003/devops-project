#!/bin/bash

cd ../terraform

IP=$(terraform output -raw instance_public_ip)

cd ../ansible

echo "[web]" > inventory
echo "$IP ansible_user=ubuntu ansible_ssh_private_key_file=/home/jahnavi/keys/devops-key.pem" >> inventory

echo "Inventory generated with IP: $IP"
