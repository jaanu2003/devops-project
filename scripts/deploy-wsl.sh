#!/usr/bin/env bash
# Run Ansible deploy from WSL (recommended on Windows).
set -euo pipefail

WSL_PROJECT="$(pwd)"

export SSH_KEY_PATH="${SSH_KEY_PATH:-/mnt/e/Jahnavi/Main/devops-project/devops-key.pem}"
export EC2_HOST="${EC2_HOST:-13.126.236.86}"
export ANSIBLE_USER="${ANSIBLE_USER:-ubuntu}"

cd "${WSL_PROJECT}"

# Copy key into WSL home — chmod on /mnt/e/... always fails (Permission denied)
bash scripts/wsl-ssh-setup.sh "${SSH_KEY_PATH}"
export SSH_KEY_PATH="${HOME}/.ssh/devops-key.pem"

bash scripts/generate_inventory.sh
cd ansible
ansible-playbook -i inventory deploy.yml

echo ""
echo "Application URL: http://${EC2_HOST}:5000"
