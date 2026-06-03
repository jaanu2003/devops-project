# Jenkins on localhost (Windows) — your setup

Use this guide if Jenkins runs on **your PC** at **http://localhost:8080** (no separate Jenkins server).

## Is localhost Jenkins OK?

| Use case | Verdict |
|----------|---------|
| Learning, college project, portfolio demo | **Yes — perfectly fine** |
| Solo developer testing CI/CD | **Yes** |
| Production / team / 24×7 deployments | **Not recommended** — use a dedicated Linux server or cloud Jenkins |

**Why localhost is OK for you:** Your pipeline only needs to reach GitHub and your EC2 public IP. Jenkins on `localhost` can SSH/Ansible to AWS the same way your terminal does.

**Caveats:**

- Your PC must be **on** when a build runs.
- Jenkins runs as the **Windows service account** — tools must be on **that** account’s PATH (see Part B).
- Pipeline uses **`sh`** (Git Bash). Configure Git Bash once (Part B).

---

## Current EC2 (use these values)

| Setting | Value |
|---------|--------|
| Public IP | `13.126.236.86` |
| Instance ID | `i-0ff50d4429c0cad98` |
| SSH user | `ubuntu` |
| App URL (after deploy) | http://13.126.236.86:5000 |

Get IP anytime:

```powershell
cd E:\Jahnavi\Main\devops-project\terraform
terraform output instance_public_ip
```

---

## Part A — Next steps (order)

### Step 1: Deploy the app once (manual, before Jenkins)

**On Windows, use WSL** (Git Bash + Python 3.11 Ansible fails with `os.get_blocking`):

```powershell
wsl
```

Then in WSL:

```bash
cd /mnt/e/Jahnavi/Main/devops-project
export SSH_KEY_PATH="/mnt/e/Jahnavi/Main/devops-project/devops-key.pem"
export EC2_HOST="13.126.236.86"
export ANSIBLE_USER=ubuntu
bash scripts/deploy-wsl.sh
```

`chmod` on `/mnt/e/.../*.pem` fails in WSL — the script copies the key to `~/.ssh/devops-key.pem` automatically.

If deploy still fails, run SSH setup once:

```bash
export EC2_HOST="13.126.236.86"
bash scripts/wsl-ssh-setup.sh /mnt/e/Jahnavi/Main/devops-project/devops-key.pem
export SSH_KEY_PATH="$HOME/.ssh/devops-key.pem"
bash scripts/deploy-wsl.sh
```

Or one command from PowerShell:

```powershell
wsl bash -lc "cd /mnt/e/Jahnavi/Main/devops-project && export SSH_KEY_PATH=/mnt/e/Jahnavi/Main/devops-project/devops-key.pem EC2_HOST=13.126.236.86 && bash scripts/deploy-wsl.sh"
```

Open **http://13.126.236.86:5000** — you should see: `Hello from Automated Jenkins Pipeline`.

### Step 2: Push project to GitHub

```powershell
cd E:\Jahnavi\Main\devops-project
git add .
git commit -m "Add Jenkins pipeline and localhost docs"
git push origin main
```

### Step 3: Install tools (for **your user** and Jenkins)

On Windows, install and verify in **PowerShell**:

```powershell
git --version
terraform --version
python --version
```

**Ansible** (pick one):

- WSL: `sudo apt install ansible` (easiest on Windows), **or**
- Windows + Python 3.11: install pinned versions (Ansible 12+ crashes with `os.get_blocking`):

```powershell
pip install -r requirements-ansible.txt
```

- Windows + Python 3.12+: `pip install ansible` is fine

**Git Bash** (required for `Jenkinsfile` `sh` steps): [Git for Windows](https://git-scm.com/download/win)

### Step 4: Configure Jenkins service PATH (important)

Jenkins does **not** use your user PATH by default.

1. **Manage Jenkins** → **System** → **Global properties** → **Environment variables**
2. Add (adjust paths to your machine):

| Name | Example value |
|------|----------------|
| `PATH+EXTRA` | `C:\Program Files\Git\bin;C:\Windows\System32\OpenSSH;C:\Users\jahna\AppData\Local\Programs\Python\Python311;C:\terraform` |

Or set Jenkins **Shell** to Git Bash:

1. **Manage Jenkins** → **System**
2. Find **Shell** (or add in `jenkins.xml` / service env) →  
   `C:\Program Files\Git\bin\bash.exe`

Restart Jenkins: services.msc → **Jenkins** → Restart.

### Step 5: Jenkins credential (SSH key) — ID must match Jenkinsfile

Jenkins may show a **UUID** in the URL (e.g. `466bc522-...`). That is not what the pipeline uses.

1. **Manage Jenkins → Credentials →** click your SSH credential.
2. Check the **ID** field (not Description):
   - Required: **`devops-ec2-ssh-key`**
   - If ID is a random UUID, **delete** and create again:
     - Kind: SSH Username with private key
     - **ID:** type manually `devops-ec2-ssh-key` (do not leave auto-generated)
     - Username: `ubuntu`
     - Private key: paste `devops-key.pem`

3. In job **Configure**, under Pipeline → if SSH fails, confirm credential ID in Jenkinsfile matches exactly.

### Step 5b: Run on built-in node (not ec2-agent)

If the log says `Running on ec2-agent`, the job runs on EC2 and Git fails (`C:\Program Files\Git\...` on Linux).

**Fix (pick one):**

- **Manage Jenkins → Nodes → ec2-agent → Disconnect** (or delete the node), **or**
- Job **Configure** → **Restrict where this project can be run** → Label: `built-in`

The updated `Jenkinsfile` uses `agent { label 'built-in' }` so builds run on your PC.

### Step 5c: “Build with Parameters” missing?

It appears **after** Jenkins loads `Jenkinsfile` from a successful checkout once.

Until then use **Build Now** — defaults are in `Jenkinsfile` (`EC2_HOST_OVERRIDE` default `13.126.236.86`).

After a successful run, **Build with Parameters** will show on the left.

### Step 6: Create Pipeline job

1. **New Item** → name: `devops-deploy` → **Pipeline** → OK
2. **Pipeline**:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - URL: `https://github.com/jaanu2003/devops-project.git`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
3. Save

### Step 7: Build with parameters

**Build with Parameters**:

| Parameter | Value |
|-----------|--------|
| RUN_TERRAFORM_APPLY | `false` |
| EC2_HOST_OVERRIDE | `13.126.236.86` |
| GIT_BRANCH | `main` |

Check console log → success → open **http://13.126.236.86:5000**.

---

## Part B — If pipeline fails on Windows

| Error | Fix |
|-------|-----|
| `os.get_blocking` in Git Bash | Don't use Python 3.11 Ansible on Windows — run deploy in **WSL**: `wsl bash scripts/deploy-wsl.sh` |
| `pipefail: invalid option` | CRLF line endings — in WSL: `sed -i 's/\r$//' scripts/*.sh` |
| `chmod: Permission denied` on `.pem` | Normal on `/mnt/e/` — use `bash scripts/deploy-wsl.sh` (copies key to `~/.ssh/`) |
| `Host key verification failed` | Run `bash scripts/wsl-ssh-setup.sh` or redeploy with updated `ansible/ansible.cfg` |
| `'sh' not found` | Install Git for Windows; set Jenkins shell to `bash.exe` |
| `ansible: not found` | Add Ansible to Jenkins PATH or run Jenkins build via WSL |
| `python3: not found` | Use `python` in PATH or install Python 3 |
| `terraform: not found` | Add terraform folder to Jenkins PATH |
| SSH / Ansible fails | Set **EC2_HOST_OVERRIDE** = current `terraform output` IP |
| Works in terminal, fails in Jenkins | Jenkins service PATH ≠ your user PATH (Part A Step 4) |

---

## Part C — Optional: poll GitHub instead of manual Build

1. Install plugin: **GitHub hook trigger for GITScm polling**
2. Job → **Build Triggers** → **GitHub hook trigger for GITScm polling**
3. Or: **Poll SCM** schedule `H/5 * * * *` (every 5 min)

For localhost only, manual **Build with Parameters** is enough for demos.

---

## Part D — AWS credentials in Jenkins (optional)

Only needed if **RUN_TERRAFORM_APPLY** = true.

- `aws-access-key-id` (Secret text)
- `aws-secret-access-key` (Secret text)

For normal deploys, keep it `false` and use **EC2_HOST_OVERRIDE**.

---

## Quick checklist

- [ ] SSH works: `ssh -i ... ubuntu@13.126.236.86`
- [ ] Manual Ansible deploy works (Step 1)
- [ ] Code pushed to GitHub
- [ ] Jenkins at http://localhost:8080
- [ ] Credential `devops-ec2-ssh-key` created
- [ ] Git Bash / PATH configured for Jenkins service
- [ ] Pipeline job built with `EC2_HOST_OVERRIDE=13.126.236.86`
