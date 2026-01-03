# SSH Key Distribution for Multi-VM Ansible Setup

## Problem
You're trying to run `ssh-copy-id` from bastion, but there's no SSH key on the bastion VM itself. The key you used to SSH to bastion is on your local machine, not on bastion.

## Solution Options

### Option 1: Use Your Local Machine as Ansible Control Node (Recommended)

This is simpler - you don't need to copy keys to bastion. Just use your local machine to manage all VMs directly.

```bash
# From your local machine, test connectivity to all VMs
ssh -i ~/.ssh/azure-vm-key azureuser@52.224.233.131   # web1
ssh -i ~/.ssh/azure-vm-key azureuser@172.191.100.145   # web2
ssh -i ~/.ssh/azure-vm-key azureuser@172.203.139.221   # web3
ssh -i ~/.ssh/azure-vm-key azureuser@172.191.205.150   # app1
ssh -i ~/.ssh/azure-vm-key azureuser@52.186.67.24      # app2
ssh -i ~/.ssh/azure-vm-key azureuser@172.191.53.150    # db1

# Test Ansible from local machine
ansible all -i ansible-inventory/dev.yml -m ping
```

### Option 2: Copy SSH Key to Bastion (If You Want Bastion as Control Node)

If you prefer to use bastion as control node, you need to copy your SSH key there:

```bash
# From your LOCAL machine, copy your SSH key to bastion
# IMPORTANT: Must use -i flag to specify which key to use for the connection
scp -i ~/.ssh/azure-vm-key ~/.ssh/azure-vm-key azureuser@172.191.211.190:~/.ssh/
scp -i ~/.ssh/azure-vm-key ~/.ssh/azure-vm-key.pub azureuser@172.191.211.190:~/.ssh/

# SSH to bastion
ssh -i ~/.ssh/azure-vm-key azureuser@172.191.211.190

# On bastion, set correct permissions
chmod 600 ~/.ssh/azure-vm-key
chmod 644 ~/.ssh/azure-vm-key.pub

# Add key to ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/azure-vm-key

# Now distribute to other VMs
for vm in 10.0.1.4 10.0.1.5 10.0.1.6 10.0.2.4 10.0.2.5 10.0.3.4; do
    ssh-copy-id -i ~/.ssh/azure-vm-key.pub azureuser@$vm
done
```

### Option 3: Generate New Key on Bastion

Generate a new SSH key specifically on bastion:

```bash
# SSH to bastion
ssh -i ~/.ssh/azure-vm-key azureuser@172.191.211.190

# Generate new key pair on bastion
ssh-keygen -t ed25519 -f ~/.ssh/bastion-key -N ""

# Copy public key to all VMs
for vm in 10.0.1.4 10.0.1.5 10.0.1.6 10.0.2.4 10.0.2.5 10.0.3.4; do
    ssh-copy-id -i ~/.ssh/bastion-key.pub azureuser@$vm
done
```

## Recommended Approach

**Use Option 1** - Manage all VMs from your local machine. This is:
- Simpler (no key copying needed)
- More secure (keys stay on your machine)
- Standard Ansible practice
- What your ansible-inventory/dev.yml already assumes

## Next Steps After Choosing Option 1

```bash
# 1. Test SSH to each VM from local machine
for ip in 52.224.233.131 172.191.100.145 172.203.139.221 172.191.205.150 52.186.67.24 172.191.53.150; do
    echo "Testing $ip..."
    ssh -i ~/.ssh/azure-vm-key -o ConnectTimeout=5 azureuser@$ip "echo 'Connected!'"
done

# 2. Test Ansible connectivity
ansible all -i ansible-inventory/dev.yml -m ping

# 3. Test specific tiers
ansible webservers -i ansible-inventory/dev.yml -m ping
ansible appservers -i ansible-inventory/dev.yml -m ping
ansible dbservers -i ansible-inventory/dev.yml -m ping

# 4. Gather facts
ansible all -i ansible-inventory/dev.yml -m setup | head -100
```

## Troubleshooting

### If SSH Connection Fails:
- Verify the VM is running: `az vm list --resource-group rg-devops-learn --show-details`
- Check NSG rules: `az network nsg rule list --resource-group rg-devops-learn --nsg-name nsg-web`
- Wait 2-3 minutes for VM to fully boot after creation

### If Ansible Ping Fails:
- Verify SSH key path in inventory file matches: `~/.ssh/azure-vm-key`
- Check Ansible is installed: `ansible --version`
- Try with verbose output: `ansible all -i ansible-inventory/dev.yml -m ping -vvv`
