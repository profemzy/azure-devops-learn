#!/bin/bash
# Phase 1: Ansible Validation Script
# Validates Ansible installation and configuration

set -euo pipefail

echo "=== Phase 1: Ansible Validation ==="
echo ""

PASS=0
FAIL=0
SKIP=0

check() {
    local name="$1"
    local result="$2"

    if [ "$result" -eq 0 ]; then
        echo "[PASS] $name"
        ((PASS++))
    elif [ "$result" -eq 2 ]; then
        echo "[SKIP] $name"
        ((SKIP++))
    else
        echo "[FAIL] $name"
        ((FAIL++))
    fi
}

# Check prerequisites
echo "--- Prerequisites ---"

if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1)
    check "Python 3 installed" 0
else
    echo "[FAIL] Python 3 not installed"
    exit 1
fi

if command -v ansible &> /dev/null; then
    ANSIBLE_VERSION=$(ansible --version | head -1)
    check "Ansible installed" 0
    echo "  $ANSIBLE_VERSION"
else
    echo "[FAIL] Ansible not installed"
    echo "  Install with: pip install ansible"
    exit 1
fi

if command -v git &> /dev/null; then
    check "Git installed" 0
else
    echo "[WARN] Git not installed (recommended for playbooks)"
fi

# Check Ansible configuration
echo ""
echo "--- Ansible Configuration ---"

if [ -f "$HOME/.ansible/ansible.cfg" ]; then
    check "Ansible config exists" 0
else
    echo "[INFO] No user config found, using defaults"
fi

if [ -d "$HOME/ansible" ]; then
    check "Ansible directory exists" 0
else
    echo "[INFO] Creating ~/ansible directory"
    mkdir -p "$HOME/ansible"
fi

# Check inventory
echo ""
echo "--- Inventory ---"

if [ -f "$HOME/ansible/inventory" ]; then
    check "Inventory file exists" 0

    # Count hosts in inventory
    HOST_COUNT=$(grep -c "ansible_host\|^\[" "$HOME/ansible/inventory" 2>/dev/null || echo "0")
    echo "  Hosts defined: $HOST_COUNT"
else
    echo "[INFO] No inventory file found"
    echo "  Creating sample inventory..."
    mkdir -p "$HOME/ansible"
    cat > "$HOME/ansible/inventory" << 'INVENTORY'
# Sample inventory - customize for your environment
[localhost]
localhost ansible_connection=local

[webservers]
# web1.example.com ansible_host=your-vm-ip

[dbservers]
# db1.example.com ansible_host=your-vm-ip

[production]
# prod-vm ansible_host=your-vm-ip ansible_user=azureuser
INVENTORY
    check "Sample inventory created" 0
fi

# Check playbooks
echo ""
echo "--- Playbooks ---"

PLAYBOOK_COUNT=$(find "$HOME/ansible" -maxdepth 2 -name "*.yml" -o -name "*.yaml" 2>/dev/null | wc -l)
if [ "$PLAYBOOK_COUNT" -gt 0 ]; then
    check "Playbooks found: $PLAYBOOK_COUNT" 0
else
    echo "[INFO] No playbooks found"
    echo "  Creating sample playbook..."
    cat > "$HOME/ansible/first-playbook.yml" << 'PLAYBOOK'
---
- name: First Ansible Playbook
  hosts: localhost
  connection: local
  gather_facts: yes

  tasks:
    - name: Display a message
      debug:
        msg: "Hello from Ansible!"
PLAYBOOK
    check "Sample playbook created" 0
fi

# Validate Ansible installation
echo ""
echo "--- Ansible Validation ---"

# Check modules directory
ANSIBLE_MODULES_DIR=$(ansible-config view BASEDIR 2>/dev/null || echo "")
if [ -d "$ANSIBLE_MODULES_DIR" ]; then
    check "Ansible modules accessible" 0
else
    # Try a simple ping to verify Ansible works
    if ansible localhost -m ping -c local 2>/dev/null; then
        check "Ansible ping successful" 0
    else
        check "Ansible ping" 1
    fi
fi

# Check for Azure collection (optional)
echo ""
echo "--- Azure Integration (Optional) ---"

if ansible-galaxy collection list 2>/dev/null | grep -q "azure"; then
    check "Azure collection installed" 0
else
    echo "[INFO] Azure collection not installed"
    echo "  Install with: ansible-galaxy collection install azure.azcollection"
    check "Azure collection" 2
fi

# Syntax check playbooks
echo ""
echo "--- Playbook Syntax ---"

for playbook in "$HOME/ansible"/*.yml "$HOME/ansible"/*.yaml; do
    if [ -f "$playbook" ]; then
        if ansible-playbook "$playbook" --syntax-check 2>/dev/null; then
            check "Syntax valid: $(basename "$playbook")" 0
        else
            check "Syntax valid: $(basename "$playbook")" 1
        fi
    fi
done

# Summary
echo ""
echo "=== Validation Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Skipped: $SKIP"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "[SUCCESS] Ansible validation passed!"
    echo ""
    echo "Next steps:"
    echo "  1. Edit ~/ansible/inventory with your hosts"
    echo "  2. Run: ansible all -m ping"
    echo "  3. Run: ansible-playbook ~/ansible/first-playbook.yml"
    exit 0
else
    echo "[INCOMPLETE] Some checks failed. Review the issues above."
    echo ""
    echo "Common fixes:"
    echo "  - Install Ansible: pip install ansible"
    echo "  - Create inventory: ~/ansible/inventory"
    echo "  - Test connection: ansible all -m ping"
    exit 1
fi