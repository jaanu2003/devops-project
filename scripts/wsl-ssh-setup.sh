#!/usr/bin/env bash
# Prepare SSH for WSL: copy .pem off /mnt/* (chmod fails there) and trust EC2 host key.
set -euo pipefail

SOURCE_KEY="${1:-${SSH_KEY_PATH:-/mnt/e/Jahnavi/Main/devops-project/devops-key.pem}}"
EC2_HOST="${EC2_HOST:-13.126.236.86}"
ANSIBLE_USER="${ANSIBLE_USER:-ubuntu}"
WSL_KEY="${HOME}/.ssh/devops-key.pem"

if [[ ! -f "${SOURCE_KEY}" ]]; then
  echo "ERROR: Key not found: ${SOURCE_KEY}" >&2
  exit 1
fi

mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

cp -f "${SOURCE_KEY}" "${WSL_KEY}"
chmod 600 "${WSL_KEY}"

# Trust EC2 host key (fixes "Host key verification failed" in Ansible)
touch "${HOME}/.ssh/known_hosts"
chmod 600 "${HOME}/.ssh/known_hosts"
if ! ssh-keygen -F "${EC2_HOST}" >/dev/null 2>&1; then
  echo "Adding ${EC2_HOST} to known_hosts..."
  ssh-keyscan -H "${EC2_HOST}" >> "${HOME}/.ssh/known_hosts" 2>/dev/null || true
fi

echo "Testing SSH to ${ANSIBLE_USER}@${EC2_HOST}..."
ssh -i "${WSL_KEY}" \
  -o StrictHostKeyChecking=accept-new \
  -o IdentitiesOnly=yes \
  -o BatchMode=yes \
  "${ANSIBLE_USER}@${EC2_HOST}" "echo SSH_OK"

echo "Key ready at ${WSL_KEY} (use this path for Ansible in WSL)"
