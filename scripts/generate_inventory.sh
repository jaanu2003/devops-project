#!/usr/bin/env bash
# Generates ansible/inventory from Terraform output or EC2_HOST env var.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANSIBLE_DIR="${REPO_ROOT}/ansible"
TERRAFORM_DIR="${REPO_ROOT}/terraform"

ANSIBLE_USER="${ANSIBLE_USER:-ubuntu}"
SSH_KEY_PATH="${SSH_KEY_PATH:?Export SSH_KEY_PATH (path to devops-key.pem)}"

if [[ -n "${EC2_HOST:-}" ]]; then
  TARGET_IP="${EC2_HOST}"
  echo "Using EC2_HOST from environment: ${TARGET_IP}"
else
  echo "Reading public IP from Terraform output..."
  cd "${TERRAFORM_DIR}"
  TARGET_IP="$(terraform output -raw instance_public_ip)"
  echo "Terraform instance_public_ip: ${TARGET_IP}"
fi

cat > "${ANSIBLE_DIR}/inventory" <<EOF
[web]
${TARGET_IP} ansible_user=${ANSIBLE_USER} ansible_ssh_private_key_file=${SSH_KEY_PATH}
EOF

echo "Wrote ${ANSIBLE_DIR}/inventory"
