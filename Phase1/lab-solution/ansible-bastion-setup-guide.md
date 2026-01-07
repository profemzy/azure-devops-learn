# Ansible Setup on Bastion Host

## Prerequisites
- SSH keys distributed to all VMs
- Bastion VM accessible at 172.191.211.190
- All VMs are running

## Step 1: SSH to Bastion

```bash
ssh -i ~/.ssh/azure-vm-key azureuser@172.191.211.190
```

## Step 2: Install Ansible on Bastion

```bash
# Update package list
sudo apt update

# Install required dependencies
sudo apt install -y python3-pip python3-venv

# Create virtual environment (recommended)
python3 -m venv ~/ansible-venv
source ~/ansible-venv/bin/activate

# Install Ansible
pip install ansible-core

# Verify installation
ansible --version
```

## Step 3: Copy Files to Bastion

```bash
# Create ansible directory on bastion
mkdir -p ~/ansible/inventory
mkdir -p ~/ansible/playbooks

# From your LOCAL machine, copy files to bastion:
scp -i ~/.ssh/azure-vm-key Phase1/lab-solution/ansible.cfg azureuser@172.191.211.190:~/ansible/
scp -i ~/.ssh/azure-vm-key Phase1/lab-solution/ansible-inventory/dev.yml azureuser@172.191.211.190:~/ansible/inventory/dev.yml
```

## Step 4: Verify ansible.cfg Configuration

The `ansible.cfg` file copied in Step 3 includes important configurations:

- **Suppresses Python interpreter warnings** - No more "discovered Python interpreter" messages
- **Disables host key checking** - For lab/testing purposes only
- **Optimizes SSH connections** - Uses pipelining and multiplexing for faster execution
- **Fact caching** - Speeds up playbook runs by caching system facts

**Note:** The YAML output callback is disabled by default to avoid plugin loading errors. If you want YAML-formatted output, install the community.general collection:
```bash
ansible-galaxy collection install community.general
```
Then uncomment the `stdout_callback` and `bin_ansible_callbacks` lines in ansible.cfg.

```bash
# View ansible.cfg (optional)
cat ~/ansible/ansible.cfg
```

## Step 5: Verify Inventory Configuration

The inventory file copied in Step 3 already has the correct configuration with:
- Private IPs for internal VNet communication
- No control node (bastion doesn't manage itself)
- `app_environment` instead of reserved word `environment`
- SSH key path configured for all hosts
- `ansible_python_interpreter: auto_legacy_silent` to suppress Python interpreter warnings

```bash
# Verify inventory file (optional)
cat ~/ansible/inventory/dev.yml
```

Expected content:
```yaml
---
all:
  children:
    webservers:
      hosts:
        web1:
          ansible_host: 10.0.1.4
          ansible_user: azureuser
          ansible_ssh_private_key_file: ~/.ssh/azure-vm-key
          app_tier: web
        web2:
          ansible_host: 10.0.1.5
          ansible_user: azureuser
          ansible_ssh_private_key_file: ~/.ssh/azure-vm-key
          app_tier: web
        web3:
          ansible_host: 10.0.1.6
          ansible_user: azureuser
          ansible_ssh_private_key_file: ~/.ssh/azure-vm-key
          app_tier: web

    appservers:
      hosts:
        app1:
          ansible_host: 10.0.2.4
          ansible_user: azureuser
          ansible_ssh_private_key_file: ~/.ssh/azure-vm-key
          app_tier: app
        app2:
          ansible_host: 10.0.2.5
          ansible_user: azureuser
          ansible_ssh_private_key_file: ~/.ssh/azure-vm-key
          app_tier: app

    dbservers:
      hosts:
        db1:
          ansible_host: 10.0.3.4
          ansible_user: azureuser
          ansible_ssh_private_key_file: ~/.ssh/azure-vm-key
          app_tier: db

  vars:
    app_environment: development
    ntp_servers:
      - 0.pool.ntp.org
      - 1.pool.ntp.org
    ansible_python_interpreter: auto_legacy_silent
```

## Step 6: Test Ansible Connectivity

```bash
# Activate ansible virtual environment
source ~/ansible-venv/bin/activate

# Test all hosts
ansible all -i ~/ansible/inventory/dev.yml -m ping

# Test specific tiers
ansible webservers -i ~/ansible/inventory/dev.yml -m ping
ansible appservers -i ~/ansible/inventory/dev.yml -m ping
ansible dbservers -i ~/ansible/inventory/dev.yml -m ping

# Expected output:
# web1 | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
# web2 | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
# ...
```

## Step 7: Gather Facts from All Hosts

```bash
# Gather comprehensive facts
ansible all -i ~/ansible/inventory/dev.yml -m setup | head -100

# Check specific facts
ansible all -i ~/ansible/inventory/dev.yml -m setup -a "filter=ansible_distribution"
ansible all -i ~/ansible/inventory/dev.yml -m setup -a "filter=ansible_memtotal_mb"
ansible all -i ~/ansible/inventory/dev.yml -m setup -a "filter=ansible_processor_vcpus"
```

## Step 8: Create Your First Multi-Tier Playbook

```bash
# Create playbook directory
mkdir -p ~/ansible/playbooks

# Create first playbook
nano ~/ansible/playbooks/basic-setup.yml
```

Paste this content:

```yaml
---
- name: Basic Multi-Tier Setup
  hosts: all
  become: true
  gather_facts: true

  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install common packages
      apt:
        name:
          - curl
          - wget
          - vim
          - git
          - htop
          - tree
        state: present

    - name: Create application user
      user:
        name: appuser
        shell: /bin/bash
        home: /home/appuser
        create_home: yes

- name: Configure Web Tier
  hosts: webservers
  become: true

  tasks:
    - name: Install nginx
      apt:
        name: nginx
        state: present

    - name: Start and enable nginx
      service:
        name: nginx
        state: started
        enabled: yes

    - name: Create custom index page
      copy:
        content: |
          <!DOCTYPE html>
          <html>
          <head>
            <title>{{ ansible_hostname }}</title>
          </head>
          <body>
            <h1>Welcome to {{ ansible_hostname }}</h1>
            <p>Server IP: {{ ansible_default_ipv4.address }}</p>
            <p>Tier: Web</p>
          </body>
          </html>
        dest: /var/www/html/index.html
        owner: www-data
        group: www-data
        mode: '0644'
      notify: restart nginx

  handlers:
    - name: restart nginx
      service:
        name: nginx
        state: restarted

- name: Configure App Tier
  hosts: appservers
  become: true

  tasks:
    - name: Install Node.js (using Ubuntu repository)
      apt:
        name:
          - nodejs
          - npm
        state: present
      # Note: This installs older Node.js, for production use NodeSource repository

    - name: Create app directory
      file:
        path: /opt/app
        state: directory
        owner: appuser
        group: appuser
        mode: '0755'

    - name: Create simple Node.js app
      copy:
        content: |
          const http = require('http');
          const port = 3000;

          const server = http.createServer((req, res) => {
            res.writeHead(200, { 'Content-Type': 'text/plain' });
            res.end(`App Server: ${process.env.HOSTNAME || 'unknown'}\n`);
          });

          server.listen(port, () => {
            console.log(`Server running at http://localhost:${port}/`);
          });
        dest: /opt/app/server.js
        owner: appuser
        group: appuser
        mode: '0644'

- name: Configure Database Tier
  hosts: dbservers
  become: true

  tasks:
    - name: Install PostgreSQL
      apt:
        name:
          - postgresql
          - postgresql-contrib
        state: present

    - name: Start and enable PostgreSQL
      service:
        name: postgresql
        state: started
        enabled: yes

    - name: Install Python PostgreSQL adapter
      apt:
        name: python3-psycopg2
        state: present
```

## Step 9: Run the Playbook

```bash
# Check playbook syntax
ansible-playbook ~/ansible/playbooks/basic-setup.yml -i ~/ansible/inventory/dev.yml --syntax-check

# Dry run (check what would change)
ansible-playbook ~/ansible/playbooks/basic-setup.yml -i ~/ansible/inventory/dev.yml --check

# Run the playbook
ansible-playbook ~/ansible/playbooks/basic-setup.yml -i ~/ansible/inventory/dev.yml

# Run with verbose output
ansible-playbook ~/ansible/playbooks/basic-setup.yml -i ~/ansible/inventory/dev.yml -v
```

## Step 10: Verify Deployment

```bash
# Test web servers
ansible webservers -i ~/ansible/inventory/dev.yml -m shell -a "curl -s localhost"
ansible webservers -i ~/ansible/inventory/dev.yml -m shell -a "systemctl status nginx"

# Test from your local machine
curl http://52.224.233.131   # web1
curl http://172.191.100.145   # web2
curl http://172.203.139.221   # web3

# Test app servers
ansible appservers -i ~/ansible/inventory/dev.yml -m shell -a "node /opt/app/server.js &"
ansible appservers -i ~/ansible/inventory/dev.yml -m shell -a "curl -s localhost:3000"

# Test database
ansible dbservers -i ~/ansible/inventory/dev.yml -m shell -a "systemctl status postgresql"
ansible dbservers -i ~/ansible/inventory/dev.yml -m shell -a "sudo -u postgres psql -c 'SELECT version();'"
```

## Step 11: Create Rolling Update Playbook

```bash
nano ~/ansible/playbooks/rolling-update.yml
```

```yaml
---
- name: Rolling Update Web Tier
  hosts: webservers
  become: true
  serial: 1  # Update one server at a time

  tasks:
    - name: Update nginx configuration
      copy:
        content: |
          worker_processes auto;
          events { worker_connections 1024; }
          http {
            server {
              listen 80;
              server_name _;
              location / {
                return 200 "{{ ansible_hostname }} - Updated\n";
                add_header Content-Type text/plain;
              }
            }
          }
        dest: /etc/nginx/nginx.conf
        owner: root
        group: root
        mode: '0644'
        backup: yes
      notify: restart nginx
      register: nginx_update

    - name: Wait for nginx to be healthy
      uri:
        url: "http://localhost"
        status_code: 200
      register: result
      until: result.status == 200
      retries: 5
      delay: 2
      when: nginx_update.changed

  handlers:
    - name: restart nginx
      service:
        name: nginx
        state: restarted
```

```bash
# Run rolling update
ansible-playbook ~/ansible/playbooks/rolling-update.yml -i ~/ansible/inventory/dev.yml -v
```

## Step 12: Create Ad-Hoc Commands Reference

```bash
# Check disk space on all hosts
ansible all -i ~/ansible/inventory/dev.yml -m shell -a "df -h"

# Check memory on all hosts
ansible all -i ~/ansible/inventory/dev.yml -m shell -a "free -h"

# Check running processes
ansible all -i ~/ansible/inventory/dev.yml -m shell -a "ps aux | head -10"

# Check system uptime
ansible all -i ~/ansible/inventory/dev.yml -m shell -a "uptime"

# Install a package on web tier
ansible webservers -i ~/ansible/inventory/dev.yml -m apt -a "name=git state=present" --become

# Restart a service on app tier
ansible appservers -i ~/ansible/inventory/dev.yml -m service -a "name=nginx state=restarted" --become

# Copy a file to all hosts
ansible all -i ~/ansible/inventory/dev.yml -m copy -a "content='Hello World\n' dest=/tmp/test.txt"

# Fetch a file from hosts
ansible all -i ~/ansible/inventory/dev.yml -m fetch -a "src=/var/log/syslog dest=/tmp/logs/"

# Check Nginx status
ansible webservers -i ~/ansible/inventory/dev.yml -m service -a "name=nginx"
```

## Step 13: Create SSH Hardening Playbook

```bash
nano ~/ansible/playbooks/ssh-hardening.yml
```

```yaml
---
- name: SSH Hardening
  hosts: all
  become: true

  tasks:
    - name: Backup SSH config
      copy:
        src: /etc/ssh/sshd_config
        dest: "/etc/ssh/sshd_config.backup.{{ ansible_date_time.epoch }}"
        remote_src: yes

    - name: Disable password authentication
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^#?PasswordAuthentication'
        line: 'PasswordAuthentication no'
        state: present

    - name: Disable root login
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^#?PermitRootLogin'
        line: 'PermitRootLogin no'
        state: present

    - name: Set idle timeout
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^#?ClientAliveInterval'
        line: 'ClientAliveInterval 300'
        state: present

    - name: Set max alive count
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^#?ClientAliveCountMax'
        line: 'ClientAliveCountMax 2'
        state: present

    - name: Limit authentication retries
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^#?MaxAuthTries'
        line: 'MaxAuthTries 3'
        state: present

    - name: Validate SSH configuration
      command: sshd -t
      register: sshd_test
      changed_when: false

    - name: Restart SSH service
      service:
        name: ssh
        state: restarted
      when: sshd_test.rc == 0
```

```bash
# Run SSH hardening
ansible-playbook ~/ansible/playbooks/ssh-hardening.yml -i ~/ansible/inventory/dev.yml -v

# Verify hardening
ansible all -i ~/ansible/inventory/dev.yml -m shell -a "sudo sshd -T | grep -E 'passwordauthentication|permitrootlogin'"
```

## Quick Reference Commands

```bash
# Activate ansible environment
source ~/ansible-venv/bin/activate

# List hosts in inventory
ansible all -i ~/ansible/inventory/dev.yml --list-hosts

# Ping all hosts
ansible all -i ~/ansible/inventory/dev.yml -m ping

# Run playbook with tags
ansible-playbook playbook.yml -i ~/ansible/inventory/dev.yml --tags "web,app"

# Run with limit to specific hosts
ansible-playbook playbook.yml -i ~/ansible/inventory/dev.yml --limit "web*"

# Check playbook syntax
ansible-playbook playbook.yml -i ~/ansible/inventory/dev.yml --syntax-check

# Dry run
ansible-playbook playbook.yml -i ~/ansible/inventory/dev.yml --check
```

## Next Steps

1. ✅ Install Ansible on bastion
2. ✅ Copy and update inventory
3. ✅ Test connectivity
4. ✅ Run basic setup playbook
5. ✅ Verify deployment
6. ✅ Practice rolling updates
7. ✅ Apply SSH hardening
8. Proceed to Phase 2: Git & Engineering Workflows

## Cleanup When Done

```bash
# Deactivate virtual environment
deactivate

# SSH out of bastion
exit

# From local machine (repo root), run the unified cleanup script
./Phase1/scripts/common/cleanup-phase1.sh
