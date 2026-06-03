#!/usr/bin/env bash
# Local / manual full pipeline: optional Terraform apply -> inventory -> Ansible deploy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

RUN_TERRAFORM="${RUN_TERRAFORM:-false}"

if [[ "${RUN_TERRAFORM}" == "true" ]]; then
  echo "==> Terraform apply"
  cd "${REPO_ROOT}/terraform"
  terraform init
  terraform apply -auto-approve
  cd "${REPO_ROOT}"
fi

echo "==> Generate Ansible inventory"
bash "${SCRIPT_DIR}/generate_inventory.sh"

echo "==> Ansible deploy"
cd "${REPO_ROOT}/ansible"
ansible-playbook -i inventory deploy.yml

TARGET_IP="${EC2_HOST:-}"
if [[ -z "${TARGET_IP}" ]]; then
  TARGET_IP="$(cd "${REPO_ROOT}/terraform" && terraform output -raw instance_public_ip)"
fi

echo ""
echo "Deployment finished."
echo "Application URL: http://${TARGET_IP}:5000"
