#!/bin/bash
# Production SSH Hardening Script
# This script implements enterprise-grade SSH security

set -euo pipefail  # Production-grade error handling

echo "[INFO] Backing up original SSH config..."
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)

echo "[INFO] Applying SSH hardening..."

# Disable password authentication (MANDATORY for production)
sudo sed -i -E 's/^\s*#?\s*PasswordAuthentication\s+yes\s*$/PasswordAuthentication no/' /etc/ssh/sshd_config

# Disable X11 forwarding (reduces attack surface)
sudo sed -i -E 's/^\s*#?\s*X11Forwarding\s+yes\s*$/X11Forwarding no/' /etc/ssh/sshd_config

# Limit authentication retries
sudo sed -i -E 's/^\s*#?\s*MaxAuthTries\s+[0-9]+\s*$/MaxAuthTries 3/' /etc/ssh/sshd_config

# Set idle timeout (prevents orphaned sessions)
sudo sed -i -E 's/^\s*#?\s*ClientAliveInterval\s+[0-9]+\s*$/ClientAliveInterval 300/' /etc/ssh/sshd_config
sudo sed -i -E 's/^\s*#?\s*ClientAliveCountMax\s+[0-9]+\s*$/ClientAliveCountMax 2/' /etc/ssh/sshd_config

# Disable root login
sudo sed -i -E 's/^\s*#?\s*PermitRootLogin\s+(yes|without-password|prohibit-password)\s*$/PermitRootLogin no/' /etc/ssh/sshd_config

# Ensure PermitRootLogin no is set (add if not present)
grep -q "^PermitRootLogin no" /etc/ssh/sshd_config || echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config

# Use a non-standard port (security through obscurity + reduces noise)
# NOTE: Before doing this, ensure you can access via the new port
# NEW_PORT=2222
# sudo sed -i "s/#Port 22/Port $NEW_PORT/" /etc/ssh/sshd_config

# Allow only specific users (principle of least privilege)
# IMPORTANT: Replace 'azureuser' with your actual username before running
# echo "AllowUsers azureuser" | sudo tee -a /etc/ssh/sshd_config

# Validate SSH configuration before restarting
echo "[INFO] Validating SSH configuration..."
VALIDATION_OUTPUT=$(sudo sshd -t 2>&1) || true
if [[ -n "$VALIDATION_OUTPUT" ]]; then
    echo "[WARN] sshd -t output: $VALIDATION_OUTPUT"
fi

# Detect and restart SSH service
echo "[INFO] Restarting SSH service..."
RESTART_SUCCESS=false

if command -v systemctl &> /dev/null; then
    # Try sshd.service first, then ssh.service
    if sudo systemctl restart sshd 2>/dev/null; then
        RESTART_SUCCESS=true
    elif sudo systemctl restart ssh 2>/dev/null; then
        RESTART_SUCCESS=true
    fi
else
    # Fallback for systems without systemctl
    if sudo service ssh restart 2>/dev/null; then
        RESTART_SUCCESS=true
    elif sudo service sshd restart 2>/dev/null; then
        RESTART_SUCCESS=true
    elif sudo /etc/init.d/ssh restart 2>/dev/null; then
        RESTART_SUCCESS=true
    elif sudo /etc/init.d/sshd restart 2>/dev/null; then
        RESTART_SUCCESS=true
    fi
fi

if [ "$RESTART_SUCCESS" = true ]; then
    echo "[SUCCESS] SSH hardening applied. Test connection in a NEW terminal before closing this one."
else
    echo "[ERROR] Failed to restart SSH service. Please restart it manually."
    echo "[ERROR] Try: sudo systemctl restart sshd OR sudo service ssh restart"
    exit 1
fi

echo "[WARNING] If you get locked out, use Azure Serial Console or: az vm run-command invoke"

