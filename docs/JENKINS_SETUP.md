# Jenkins setup — step by step

This guide wires Jenkins to deploy this repo to your EC2 instance using the `Jenkinsfile` in the repository root.

> **Using Jenkins on your PC (`http://localhost:8080`)?**  
> Skip “install on Linux server” — use **[JENKINS_LOCALHOST.md](JENKINS_LOCALHOST.md)** instead.

## Your environment (reference)

| Setting | Value |
|---------|--------|
| AWS region | `ap-south-1` |
| EC2 instance ID | `i-0ff50d4429c0cad98` |
| EC2 public IP (current) | `13.126.236.86` |
| Security group ID | `sg-017c044cde0bc6d19` |
| Key pair name in AWS | `devops-key` |
| SSH user on EC2 | `ubuntu` |
| App port | `5000` |
| App URL | http://13.126.236.86:5000 |

If you run `terraform destroy` / `apply` again, update Jenkins parameter **EC2_HOST_OVERRIDE** or re-run Terraform so inventory picks up the new IP.

---

## Part A — Install Jenkins

### Option 1: Jenkins on Linux (recommended)

```bash
sudo apt update
sudo apt install -y openjdk-17-jre git ansible terraform python3-pip
sudo pip3 install ansible

# Jenkins LTS (Ubuntu/Debian)
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install -y jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Open `http://<jenkins-server-ip>:8080`, complete setup wizard, install suggested plugins.

### Option 2: Jenkins on Windows

1. Install [Jenkins LTS for Windows](https://www.jenkins.io/download/).
2. Install [Git for Windows](https://git-scm.com/download/win).
3. Install Ansible + Terraform in **WSL Ubuntu** and configure Jenkins to run builds on a **Linux** agent (recommended), or run pipeline steps in "Execute shell" via Git Bash with paths adjusted.

> Pipelines use `sh` steps — a Linux agent avoids most Windows path issues.

---

## Part B — Install tools on the Jenkins agent

On the machine that runs the job (master or agent):

```bash
git --version
terraform --version
ansible --version
python3 --version
```

AWS CLI (only if Jenkins will run `terraform apply`):

```bash
aws configure
# Access Key ID, Secret, region: ap-south-1
```

---

## Part C — Jenkins credentials

In Jenkins: **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**

### 1) SSH key for EC2 (required)

| Field | Value |
|-------|--------|
| Kind | **SSH Username with private key** |
| ID | `devops-ec2-ssh-key` |
| Username | `ubuntu` |
| Private Key | Enter directly → paste contents of **`devops-key.pem`** |

This ID must match `credentialsId` in `Jenkinsfile`.

### 2) AWS keys (optional — only if `RUN_TERRAFORM_APPLY` is checked)

Create two **Secret text** credentials:

| ID | Secret |
|----|--------|
| `aws-access-key-id` | Your IAM access key |
| `aws-secret-access-key` | Your IAM secret key |

IAM user needs at least: `ec2:*` (or scoped policy for run instances, security groups, describe).

If you **do not** want Jenkins to run Terraform, skip AWS credentials and leave **RUN_TERRAFORM_APPLY** unchecked. Use parameter **EC2_HOST_OVERRIDE** = `13.126.236.86`.

---

## Part D — Create the Jenkins job

1. **New Item** → name: `devops-project-deploy` → type **Pipeline** → OK.
2. **Pipeline** section:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/jaanu2003/devops-project.git`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
3. Save.

---

## Part E — Run the pipeline

1. Click **Build with Parameters**.
2. Recommended first run:

| Parameter | Value |
|-----------|--------|
| RUN_TERRAFORM_APPLY | `false` (infra already exists) |
| EC2_HOST_OVERRIDE | `13.126.236.86` |
| GIT_BRANCH | `main` |

3. Click **Build**.

### What each stage does

| Stage | Action |
|-------|--------|
| Checkout | Clones this repo on the agent |
| Validate | `py_compile` + `terraform validate` |
| Terraform Apply | Only if parameter true — creates/updates EC2 |
| Deploy to EC2 | Writes `ansible/inventory`, runs `ansible/deploy.yml` on `13.126.236.86` |

4. On success, open **http://13.126.236.86:5000**.

---

## Part F — Manual deploy (same as Jenkins, on your PC)

**PowerShell** (paths for your machine):

```powershell
cd E:\Jahnavi\Main\devops-project
$env:SSH_KEY_PATH = "E:\Jahnavi\Main\devops-project\devops-key.pem"
$env:EC2_HOST = "13.126.236.86"
$env:ANSIBLE_USER = "ubuntu"
```

**Git Bash / WSL**:

```bash
cd /e/Jahnavi/Main/devops-project
export SSH_KEY_PATH="/e/Jahnavi/Main/devops-project/devops-key.pem"
export EC2_HOST="13.126.236.86"
export ANSIBLE_USER=ubuntu
bash scripts/generate_inventory.sh
cd ansible && ansible-playbook -i inventory deploy.yml
```

---

## Part G — Full flow from scratch (no Jenkins)

Run in order:

```powershell
# 1. Clone
git clone https://github.com/jaanu2003/devops-project.git
cd devops-project

# 2. Terraform
cd terraform
terraform init
terraform apply
terraform output
cd ..

# 3. Deploy (Git Bash)
export SSH_KEY_PATH="/e/Jahnavi/Main/devops-project/devops-key.pem"
bash scripts/full_deploy.sh
```

---

## Part H — Push changes so Jenkins uses new structure

On your dev machine:

```powershell
cd E:\Jahnavi\Main\devops-project
git add Jenkinsfile scripts/ ansible/ docs/ README.md .gitignore terraform/versions.tf
git status
git commit -m "Add Jenkins pipeline and deployment scripts"
git push origin main
```

Then run the Jenkins job again (it pulls `main` on the server during Ansible `git` task).

---

## Part I — Verify on EC2

SSH in:

```powershell
ssh -i E:\Jahnavi\Main\devops-project\devops-key.pem ubuntu@13.126.236.86
```

On the server:

```bash
docker ps
docker logs flask-container
curl -s http://localhost:5000
```

---

## Part J — Optional: webhook / automatic builds

1. Install Jenkins plugin **GitHub hook trigger for GITScm polling** (or **Generic Webhook Trigger**).
2. In job: **Build Triggers** → **GitHub hook trigger for GITScm polling**.
3. In GitHub repo → Settings → Webhooks → Payload URL:  
   `http://<jenkins-url>/github-webhook/`

Each push to `main` can trigger deploy (use carefully in production).

---

## Checklist

- [ ] EC2 instance `i-0ff50d4429c0cad98` is **running**
- [ ] Security group allows **22** and **5000** from your Jenkins agent IP (or `0.0.0.0/0` for lab)
- [ ] Credential `devops-ec2-ssh-key` exists with username `ubuntu`
- [ ] `EC2_HOST_OVERRIDE` or Terraform state IP is **13.126.236.86**
- [ ] GitHub repo is public or EC2 can clone it
- [ ] Jenkins agent has `ansible`, `git`, `terraform`, `python3`

---

## Common errors

**`Host key verification failed`**  
Run once from Jenkins agent:  
`ssh -o StrictHostKeyChecking=accept-new -i <key> ubuntu@13.126.236.86`

**`terraform output` fails in Jenkins**  
No state file on agent — set **EC2_HOST_OVERRIDE** to `13.126.236.86`.

**`Credentials 'devops-ec2-ssh-key' not found`**  
Create credential with exact ID from Part C.

**Docker permission denied on EC2**  
`userdata.sh` adds `ubuntu` to `docker` group; reboot instance once if needed:  
`sudo reboot`
