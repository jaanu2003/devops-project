# DevOps Project — Terraform + Ansible + Docker + Jenkins

Flask app deployed to AWS EC2 with Docker. Infrastructure is defined in Terraform; deployment is automated with Ansible and Jenkins.

## Project layout

```
devops-project/
├── Jenkinsfile              # Jenkins pipeline
├── app.py                   # Flask application
├── requirements.txt
├── Dockerfile
├── scripts/
│   ├── generate_inventory.sh
│   └── full_deploy.sh
├── terraform/               # AWS EC2 + security group
├── ansible/
│   ├── deploy.yml
│   ├── group_vars/all.yml
│   └── inventory.example
└── docs/
    └── JENKINS_SETUP.md     # Full Jenkins + manual steps
```

## Your current AWS resources (from local Terraform state)

| Item | Value |
|------|--------|
| **Region** | `ap-south-1` (Mumbai) |
| **EC2 public IP** | `13.126.236.86` |
| **Instance type** | `t3.micro` |
| **Key pair name (AWS)** | `devops-key` |
| **Security group** | `devops-security-group` |
| **EC2 tag Name** | `terraform-server` |
| **App URL** | http://13.126.236.86:5000 |

> IPs change if you destroy/recreate the instance. Always run `terraform output` or use `scripts/generate_inventory.sh` before deploy.

Older IPs seen in old inventory files (`3.110.214.38`) are **stale** — use the IP from Terraform state above.

## Prerequisites

Install on the machine that runs deploys (your PC or Jenkins agent):

- [Git](https://git-scm.com/)
- [Terraform](https://www.terraform.io/downloads) >= 1.3
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
- [AWS CLI](https://aws.amazon.com/cli/) configured (`aws configure`)
- SSH key: `devops-key.pem` (pair for AWS key name `devops-key`)
- Docker (only needed on EC2; installed by `userdata.sh`)

**Jenkins:** use a **Linux** agent (or WSL) with `git`, `terraform`, `ansible`, and `python3` on `PATH`. See [docs/JENKINS_SETUP.md](docs/JENKINS_SETUP.md).

---

## Quick start — manual commands (Windows PowerShell)

Set paths once per session (adjust key path to where your `.pem` file lives):

```powershell
cd E:\Jahnavi\Main\devops-project

$env:SSH_KEY_PATH = "E:\Jahnavi\Main\devops-project\devops-key.pem"
$env:ANSIBLE_USER = "ubuntu"
# Optional: skip terraform output and pin IP
# $env:EC2_HOST = "13.126.236.86"
```

### 1) One-time: AWS key pair

In AWS Console (region **ap-south-1**): EC2 → Key Pairs → ensure **`devops-key`** exists and you have `devops-key.pem`.

### 2) Provision infrastructure (first time or after destroy)

```powershell
cd terraform
terraform init
terraform plan
terraform apply
terraform output
cd ..
```

Note `instance_public_ip` (currently **13.126.236.86**).

### 3) Test SSH to EC2

```powershell
ssh -i $env:SSH_KEY_PATH ubuntu@13.126.236.86
```

Type `exit` when connected successfully.

### 4) Generate inventory + deploy

Using Git Bash or WSL (Ansible deploy script is bash):

```bash
cd /e/Jahnavi/Main/devops-project
export SSH_KEY_PATH="/e/Jahnavi/Main/devops-project/devops-key.pem"
export ANSIBLE_USER=ubuntu
bash scripts/generate_inventory.sh
cd ansible && ansible-playbook -i inventory deploy.yml
```

Or full pipeline from repo root:

```bash
export SSH_KEY_PATH="/e/Jahnavi/Main/devops-project/devops-key.pem"
export RUN_TERRAFORM=false
bash scripts/full_deploy.sh
```

### 5) Verify app

Open in browser: **http://13.126.236.86:5000**  
Expected text: `Hello from Automated Jenkins Pipeline`

---

## Jenkins

Pipeline file: **`Jenkinsfile`**.

- **Localhost (Windows, `http://localhost:8080`):** **[docs/JENKINS_LOCALHOST.md](docs/JENKINS_LOCALHOST.md)**
- **Separate Jenkins server:** **[docs/JENKINS_SETUP.md](docs/JENKINS_SETUP.md)**

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Ansible `os.get_blocking` in Git Bash | Use **WSL**: `wsl bash scripts/deploy-wsl.sh` (see docs/JENKINS_LOCALHOST.md) |
| SSH timeout | Check EC2 running, IP correct, SG allows port 22, key path correct |
| Ansible “could not resolve host” | Regenerate `ansible/inventory` with `scripts/generate_inventory.sh` |
| Port 5000 not loading | On EC2: `docker ps` and `docker logs flask-container` |
| Terraform key pair error | Create `devops-key` in `ap-south-1` or change `key_name` in `terraform/main.tf` |

---

## GitHub repo

Default clone URL on server: `https://github.com/jaanu2003/devops-project.git` (branch `main`). Override with env vars `GIT_REPO_URL` and `APP_DEPLOY_BRANCH`.
