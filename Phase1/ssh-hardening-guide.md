# SSH Hardening Guide for Azure Linux VMs

This guide provides enterprise-grade SSH security hardening for Linux virtual machines.

---

## Table of Contents

1. [Overview](#overview)
2. [Why SSH Hardening Matters](#why-ssh-hardening-matters)
3. [Prerequisites](#prerequisites)
4. [Step-by-Step Hardening](#step-by-step-hardening)
5. [Using the Automated Script](#using-the-automated-script)
6. [Verification & Expected Outcomes](#verification--expected-outcomes)
7. [Recovery Procedures](#recovery-procedures)
8. [Best Practices](#best-practices)

---

## Overview

SSH (Secure Shell) is the primary method for remote administration of Linux systems. By default, SSH configurations are not production-ready. This guide covers essential security configurations to protect your Azure VMs from common attack vectors.

---

## Why SSH Hardening Matters

| Threat | Risk Level | Impact |
|--------|------------|--------|
| Brute-force attacks | High | Unauthorized access |
| Root login exploits | High | Full system compromise |
| Idle sessions | Medium | Unauthorized access via unattended sessions |
| Password guessing | High | Complete system takeover |

---

## Prerequisites

Before proceeding, ensure you have:

- [ ] Azure Linux VM (Ubuntu 18.04+, RHEL 7+, CentOS 7+, or Debian 10+)
- [ ] Sudo access to the VM
- [ ] A non-root user account with sudo privileges
- [ ] SSH key-based authentication already configured and tested
- [ ] A second terminal session open for recovery

---

## Step-by-Step Hardening

### Step 1: Backup Original Configuration

**Why:** Allows rollback if something goes wrong.

```bash
# Create timestamped backup
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)

# Verify backup exists
ls -la /etc/ssh/sshd_config.backup.*
```

**Expected Output:** Backup file listed in `/etc/ssh/`

---

### Step 2: Disable Password Authentication

**Why:** Passwords are vulnerable to brute-force attacks. SSH keys are much more secure.

```bash
# Check current setting
sudo sshd -T | grep -i passwordauthentication

# Disable password authentication
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication no/' /etc/ssh/sshd_config
```

**Verification:**
```bash
sudo sshd -T | grep -i passwordauthentication
```

**Expected Outcome:**
```
passwordauthentication no
```

---

### Step 3: Disable Root Login

**Why:** Root login makes accountability difficult and increases attack surface.

The `PermitRootLogin` directive values:

| Value | Description | Security Level |
|-------|-------------|----------------|
| `yes` | Allow root login with any method | ❌ Insecure |
| `without-password` | Allow only key-based root login | ⚠️ Partial |
| `prohibit-password` | Same as without-password | ⚠️ Partial |
| `no` | Disallow all root login | ✅ Secure |

```bash
# Check current setting
sudo sshd -T | grep -i permitrootlogin

# Disable root login (handles all variations)
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/PermitRootLogin without-password/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
```

**Verification:**
```bash
sudo sshd -T | grep -i permitrootlogin
```

**Expected Outcome:**
```
permitrootlogin no
```

---

### Step 4: Disable X11 Forwarding

**Why:** X11 forwarding adds unnecessary attack surface and is rarely needed for server administration.

```bash
# Check current setting
sudo sshd -T | grep -i x11forwarding

# Disable X11 forwarding
sudo sed -i 's/#X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config
sudo sed -i 's/X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config
```

**Verification:**
```bash
sudo sshd -T | grep -i x11forwarding
```

**Expected Outcome:**
```
x11forwarding no
```

---

### Step 5: Limit Authentication Retries

**Why:** Reduces effectiveness of brute-force attacks by limiting login attempts.

```bash
# Check current setting
sudo sshd -T | grep -i maxauthtries

# Limit to 3 retries
sudo sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
sudo sed -i 's/MaxAuthTries [0-9]*/MaxAuthTries 3/' /etc/ssh/sshd_config
```

**Verification:**
```bash
sudo sshd -T | grep -i maxauthtries
```

**Expected Outcome:**
```
maxauthtries 3
```

---

### Step 6: Configure Idle Timeout

**Why:** Prevents orphaned sessions from remaining open indefinitely.

```bash
# Check current settings
sudo sshd -T | grep -E 'clientaliveinterval|clientalivecountmax'

# Set ClientAliveInterval (seconds before checking client responsiveness)
sudo sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 300/' /etc/ssh/sshd_config
sudo sed -i 's/ClientAliveInterval [0-9]*/ClientAliveInterval 300/' /etc/ssh/sshd_config

# Set ClientAliveCountMax (number of checks before disconnecting)
sudo sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 2/' /etc/ssh/sshd_config
sudo sed -i 's/ClientAliveCountMax [0-9]*/ClientAliveCountMax 2/' /etc/ssh/sshd_config
```

**Verification:**
```bash
sudo sshd -T | grep -E 'clientaliveinterval|clientalivecountmax'
```

**Expected Outcome:**
```
clientaliveinterval 300
clientalivecountmax 2
```

**Behavior:** Session disconnects after 10 minutes of inactivity (300s × 2 = 600s = 10 min)

---

### Step 7: Validate Configuration

**Why:** Catches syntax errors before restarting SSH service.

```bash
# Test configuration syntax
sudo sshd -t

# If no output, configuration is valid
echo $?  # Should return 0
```

**Expected Outcome:** No output (silent success), exit code 0

---

### Step 8: Restart SSH Service

**Why:** Applies the new configuration.

```bash
# For systemd-based systems (Ubuntu 16.04+, RHEL 7+, CentOS 7+)
sudo systemctl restart sshd

# Alternative service name on some distributions
sudo systemctl restart ssh

# For SysV init systems (older distributions)
sudo service ssh restart
```

**Verification:**
```bash
# Check service status
sudo systemctl status ssh --no-pager

# Verify SSH is listening
sudo ss -tlnp | grep ssh
```

**Expected Outcome:** Service shows "active (running)"

---

## Using the Automated Script

The `scripts/01-ssh-hardening.sh` script automates all steps above.

### Before Running

1. Ensure you have a non-root user with sudo access
2. Test SSH key access in a separate terminal
3. Keep a recovery terminal session open
4. Verify the backup exists

### Running the Script

```bash
# Upload the script to VM
scp scripts/01-ssh-hardening.sh azureuser@$VM_IP:~/

# Make executable
chmod +x 01-ssh-hardening.sh

# Run with sudo
sudo ./01-ssh-hardening.sh
```

### Script Output (Expected)

```
[INFO] Backing up original SSH config...
[INFO] Applying SSH hardening...
[INFO] Validating SSH configuration...
[INFO] Restarting SSH service...
[SUCCESS] SSH hardening applied. Test connection in a NEW terminal before closing this one.
[WARNING] If you get locked out, use Azure Serial Console or: az vm run-command invoke
```

---

## Verification & Expected Outcomes

Run this comprehensive verification:

```bash
# Check all hardened settings
sudo sshd -T | grep -E 'passwordauthentication|permitrootlogin|x11forwarding|maxauthtries|clientaliveinterval|clientalivecountmax'
```

### Expected Final Configuration

| Setting | Value | Status |
|---------|-------|--------|
| PasswordAuthentication | no | ✅ |
| PermitRootLogin | no | ✅ |
| X11Forwarding | no | ✅ |
| MaxAuthTries | 3 | ✅ |
| ClientAliveInterval | 300 | ✅ |
| ClientAliveCountMax | 2 | ✅ |

### Functional Test

```bash
# From a NEW terminal (before closing current one)
ssh azureuser@<VM_IP>

# Verify you can sudo
sudo whoami

# Verify password auth is disabled (should fail)
ssh -o PreferredAuthentications=password azureuser@<VM_IP>
```

**Expected Outcome:** Key-based login works, password login is rejected

---

## Recovery Procedures

### If Locked Out

#### Option 1: Azure Serial Console

1. Go to Azure Portal → Your VM → Serial Console
2. Login with local credentials
3. Restore backup:
   ```bash
   sudo cp /etc/ssh/sshd_config.backup.$(date +%Y%m%d) /etc/ssh/sshd_config
   sudo systemctl restart sshd
   ```

#### Option 2: Azure Run Command

```bash
az vm run-command invoke \
  --resource-group myResourceGroup \
  --name myVM \
  --command-id RunShellScript \
  --scripts "sudo cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config && sudo systemctl restart sshd"
```

#### Option 3: Azure Bastion

Use Azure Bastion for secure browser-based SSH access.

---

## Best Practices

1. **Always backup** before making changes
2. **Test in dev first** - Apply changes to test VMs before production
3. **Keep a recovery session open** - Never close your last SSH session
4. **Use Azure Serial Console** as your recovery mechanism
5. **Rotate SSH keys regularly** - Replace keys periodically
6. **Use key-based authentication only** - Disable passwords entirely
7. **Restrict by IP** - Use Azure NSG to allow SSH only from trusted IPs
8. **Monitor login attempts** - Check `/var/log/auth.log` or `/var/log/secure`

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `sudo sshd -T` | Show full effective SSH config |
| `sudo sshd -t` | Test config syntax |
| `sudo systemctl restart sshd` | Restart SSH service |
| `sudo ss -tlnp \| grep ssh` | Check SSH listening ports |
| `tail -f /var/log/auth.log` | Monitor SSH login attempts (Ubuntu) |
| `tail -f /var/log/secure` | Monitor SSH login attempts (RHEL/CentOS) |
