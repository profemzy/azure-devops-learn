# Phase 1: Ansible Configuration Management

This guide introduces Ansible for configuration management, building on your bash scripting knowledge from Phase 1. Ansible extends automation beyond scripts to declarative, idempotent infrastructure management.

---

## Table of Contents

1. [Why Ansible After Bash?](#why-ansible-after-bash)
2. [Ansible Architecture](#ansible-architecture)
3. [Lab 1.10: Install Ansible](#lab-110-install-ansible)
4. [Lab 1.11: Inventory & Host Patterns](#lab-111-inventory--host-patterns)
5. [Lab 1.12: Your First Playbook](#lab-112-your-first-playbook)
6. [Lab 1.13: Common Modules](#lab-113-common-modules)
7. [Lab 1.14: Variables & Facts](#lab-114-variables--facts)
8. [Lab 1.15: Handlers & Conditionals](#lab-115-handlers--conditionals)
9. [Lab 1.16: Azure VM Configuration](#lab-116-azure-vm-configuration)
10. [Lab 1.17: Multi-Node Management](#lab-117-multi-node-management)
11. [Lab 1.18: Ansible with Azure Managed Identity](#lab-118-ansible-with-azure-managed-identity)
12. [Interview Reinforcement](#interview-reinforcement)

---

## Why Ansible After Bash

| Aspect | Bash Scripts | Ansible Playbooks |
|--------|--------------|-------------------|
| **Paradigm** | Imperative (step-by-step) | Declarative (desired state) |
| **Idempotency** | Manual implementation | Built-in |
| **Error Handling** | Manual `set -e` | Automatic |
| **Scale** | Difficult at scale | Designed for many hosts |
| **Syntax** | Shell-specific | YAML (human-readable) |
| **Drift Detection** | None | Checks current state |
| **Reusability** | Copy/paste | Roles and modules |

### From Bash to Ansible

Your bash scripting knowledge transfers directly:

| Bash Concept | Ansible Equivalent |
|--------------|-------------------|
| `if/else` | `when: condition` |
| `for loop` | `loop: []` |
| Functions | Tasks with `name:` |
| Exit codes | `failed_when:` |
| Variables | `vars:` and `{{ var }}` |

---

## Ansible Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Control Node                        │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │ Ansible │  │ Playbook│  │  Role   │  │ Galaxy  │        │
│  │  CLI    │  │  (.yml) │  │         │  │         │        │
│  └────┬────┘  └─────────┘  └─────────┘  └─────────┘        │
│       │                                                     │
│  ┌────┴────┐                                               │
│  │ Python  │  ← Requires Python on control node             │
│  └────┬────┘                                               │
│       │                                                     │
│  ┌────┴────┐                                               │
│  │  SSH    │  ← Connects to managed nodes                   │
│  └─────────┘                                               │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ SSH
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Managed Nodes                          │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                     │
│  │ VM 1    │  │ VM 2    │  │ VM 3    │  ← Requires Python  │
│  │ Linux   │  │ Linux   │  │ Linux   │                     │
│  └─────────┘  └─────────┘  └─────────┘                     │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Purpose |
|-----------|---------|
| **Inventory** | List of managed hosts (`/etc/ansible/hosts`) |
| **Playbook** | YAML file defining automation tasks |
| **Task** | Single unit of work (like a bash command) |
| **Module** | Pre-built actions (like `apt`, `file`, `service`) |
| **Role** | Reusable playbook structure |
| **Plugin** | Extended functionality |

---

## Lab 1.10: Install Ansible

### macOS Installation

```bash
# Using pip (recommended)
python3 -m pip install --user ansible

# Or using Homebrew
brew install ansible

# Verify installation
ansible --version
```

### Linux (on Azure VM)

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible

# RHEL/CentOS/Fedora
sudo dnf install -y ansible

# Verify
ansible --version
```

### Control Node Requirements

```bash
# Check Python version
python3 --version  # Must be 3.x

# Check SSH connectivity
ssh -V

# Check connectivity to your Azure VM
ssh azureuser@<your-vm-ip> "uname -a"
```

### Ansible Configuration File

```bash
# Create user configuration
mkdir -p ~/.ansible
cat > ~/.ansible/ansible.cfg << 'EOF'
[defaults]
inventory = ~/ansible/inventory
host_key_checking = False
deprecation_warnings = False
interpreter_python = auto_silent
stdout_callback = yaml

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False

[colors]
highlight = white
verbose = blue
warn = bright purple
error = red
diff = green
EOF

mkdir -p ~/ansible
```

---

## Lab 1.11: Inventory & Host Patterns

### Static Inventory File

```bash
# ~/ansible/inventory
# Single host
[webservers]
web1.example.com

[webservers:vars]
http_port = 80

# Multiple hosts
[dbservers]
db1.example.com ansible_host=10.0.0.10
db2.example.com ansible_host=10.0.0.11

# Azure VM (replace with your IP)
[production]
prod-vm ansible_host=20.1.2.3 ansible_user=azureuser

[production:vars]
ansible_ssh_private_key_file=~/.ssh/azure-vm-key

# Host groups
[all:vars]
environment = development
```

### Dynamic Inventory for Azure

```bash
# Install Azure collection for dynamic inventory
ansible-galaxy collection install azure.azcollection

# Create dynamic inventory script
cat > ~/ansible/azure_inventory.py << 'EOF'
#!/usr/bin/env python3
"""
Azure dynamic inventory for Ansible
Requires: pip install azure-identity azure-mgmt-resource
"""

import os
from azure.identity import DefaultAzureCredential
from azure.mgmt.resource import ResourceManagementClient

def get_inventory():
    credential = DefaultAzureCredential()
    subscription_id = os.environ.get('AZURE_SUBSCRIPTION_ID')

    if not subscription_id:
        print("Error: AZURE_SUBSCRIPTION_ID not set")
        return {"_meta": {"hostvars": {}}}

    client = ResourceManagementClient(credential, subscription_id)

    inventory = {"_meta": {"hostvars": {}}}

    for vm in client.resources.list():
        if vm.type == "Microsoft.Compute/virtualMachines":
            # Extract VM name and IP (simplified)
            inventory.setdefault("azure_vms", []).append(vm.name)

    return inventory

if __name__ == "__main__":
    import json
    print(json.dumps(get_inventory(), indent=2))
EOF

chmod +x ~/ansible/azure_inventory.py
```

### Host Patterns

```bash
# Test connectivity
ansible all -m ping

# Pattern examples
ansible webservers -m ping              # Single group
ansible db*,web* -m ping                # Wildcards
ansible 10.0.0.* -m ping                # IP range
ansible prod:staging -m ping            # Union (prod OR staging)
ansible prod:&webserver -m ping         # Intersection (prod AND webserver)
ansible '!staging' -m ping              # Exclusion
```

---

## Lab 1.12: Your First Playbook

### Basic Playbook Structure

```yaml
# ~/ansible/first-playbook.yml
---
- name: Configure web server
  hosts: webservers
  become: true
  tasks:
    - name: Install nginx
      apt:
        name: nginx
        state: present
        update_cache: yes

    - name: Ensure nginx is running
      service:
        name: nginx
        state: started
        enabled: yes
```

### Run the Playbook

```bash
# Syntax check
ansible-playbook first-playbook.yml --syntax-check

# Dry run (check mode)
ansible-playbook first-playbook.yml --check

# Run the playbook
ansible-playbook first-playbook.yml -v

# Run with limit to specific host
ansible-playbook first-playbook.yml --limit web1.example.com
```

### Verbosity Levels

```bash
# No verbose: Summary output
ansible-playbook first-playbook.yml

# -v: Task results
ansible-playbook first-playbook.yml -v

# -vv: Connection details
ansible-playbook first-playbook.yml -vv

# -vvv: Script execution
ansible-playbook first-playbook.yml -vvv

# -vvvv: Network debug
ansible-playbook first-playbook.yml -vvvv
```

---

## Lab 1.13: Common Modules

### Package Management

```yaml
# Ubuntu/Debian
- name: Install packages (Debian)
  apt:
    name:
      - nginx
      - git
      - curl
    state: present
    update_cache: yes

# RHEL/CentOS
- name: Install packages (RHEL)
  dnf:
    name: httpd
    state: present

# With version
- name: Install specific version
  apt:
    name: nginx=1.24.0
    state: present
```

### File Management

```yaml
# Create directory
- name: Create directory
  file:
    path: /opt/myapp
    state: directory
    mode: '0755'
    owner: azureuser
    group: azureuser

# Create file with content
- name: Create configuration file
  copy:
    content: |
      # My App Config
      DB_HOST=localhost
      DB_PORT=5432
    dest: /opt/myapp/config.conf
    mode: '0644'

# Create from template
- name: Create config from template
  template:
    src: templates/app.conf.j2
    dest: /opt/myapp/app.conf
    mode: '0644'
  notify: Restart app

# Set attributes (permissions, ownership)
- name: Set file attributes
  file:
    path: /opt/myapp/script.sh
    mode: '0755'
    owner: azureuser
```

### Service Management

```yaml
# Start and enable service
- name: Ensure service is running
  service:
    name: nginx
    state: started
    enabled: yes

# Restart service
- name: Restart service
  service:
    name: myapp
    state: restarted

# Stop service
- name: Stop service
  service:
    name: myapp
    state: stopped
```

### User Management

```yaml
# Create user
- name: Create deployment user
  user:
    name: deploy
    password: "{{ 'SecurePass123!' | password_hash('sha512') }}"
    groups: sudo
    append: yes
    shell: /bin/bash
    state: present

# Remove user
- name: Remove user
  user:
    name: olduser
    state: absent
```

### Git Module

```yaml
# Clone repository
- name: Clone application repository
  git:
    repo: https://github.com/example/myapp.git
    dest: /opt/myapp
    version: main
    update: yes
    force: yes

# Clone with SSH key
- name: Clone with deploy key
  git:
    repo: git@github.com:example/myapp.git
    dest: /opt/myapp
    key_file: ~/.ssh/deploy_key
```

### Shell/Command Modules

```yaml
# Use shell (for complex commands)
- name: Run complex command
  shell: |
    cd /opt/myapp
    ./build.sh --production
  args:
    executable: /bin/bash
  register: build_output

# Use command (simpler, no shell features)
- name: Get system info
  command: uname -a
  register: sysinfo

# Run only if condition met
- name: Run migration
  command: python manage.py migrate
  args:
    chdir: /opt/myapp
  when: database_ready.stat.exists
```

---

## Lab 1.14: Variables & Facts

### Defining Variables

```yaml
# In playbook
- name: Configure application
  hosts: all
  vars:
    app_name: myapp
    app_port: 8080
    app_user: azureuser
    app_dir: /opt/{{ app_name }}
```

### Variable Files

```yaml
# group_vars/all.yml (applies to all hosts)
---
app_name: myapp
environment: development
log_level: info

# group_vars/production.yml
---
app_name: myapp
environment: production
log_level: warning
app_port: 443

# host_vars/web1.example.com
---
app_port: 8080
```

### Using Variables

```yaml
- name: Create app config
  template:
    src: templates/config.j2
    dest: /opt/{{ app_name }}/config.conf

# Using in conditionals
- name: Install production packages
  apt:
    name: nginx
  when: environment == "production"
```

### Ansible Facts (System Information)

```yaml
- name: Gather facts
  hosts: all
  tasks:
    - name: Display system facts
      debug:
        msg: |
          Hostname: {{ ansible_hostname }}
          IP Address: {{ ansible_default_ipv4.address }}
          OS Family: {{ ansible_os_family }}
          Distribution: {{ ansible_distribution }} {{ ansible_distribution_version }}
          Memory: {{ (ansible_memory_mb.real.total / 1024) | round(1) }}GB
          CPU: {{ ansible_processor_vcpus }} cores

    - name: Create directory using fact
      file:
        path: /opt/{{ ansible_hostname }}
        state: directory
```

### Custom Facts

```yaml
# On managed node: /etc/ansible/facts.d/custom.fact
[app]
version=1.0.0
install_dir=/opt/myapp

# In playbook
- name: Read custom facts
  setup:
    filter: ansible_local

- name: Display custom fact
  debug:
    msg: "App version: {{ ansible_local.custom.app.version }}"
```

---

## Lab 1.15: Handlers & Conditionals

### Handlers (Triggered Tasks)

```yaml
- name: Configure nginx
  hosts: webservers
  become: true
  handlers:
    - name: Restart nginx
      service:
        name: nginx
        state: restarted

    - name: Reload nginx
      service:
        name: nginx
        state: reloaded

  tasks:
    - name: Install nginx
      apt:
        name: nginx
        state: present
      notify: Restart nginx

    - name: Copy nginx config
      copy:
        src: files/nginx.conf
        dest: /etc/nginx/nginx.conf
      notify: Reload nginx
```

### Conditionals

```yaml
- name: Configure based on OS
  hosts: all
  tasks:
    - name: Install on Debian
      apt:
        name: nginx
      when: ansible_os_family == "Debian"

    - name: Install on RedHat
      dnf:
        name: nginx
      when: ansible_os_family == "RedHat"

    - name: Install on production only
      apt:
        name: monitoring-agent
      when: environment == "production"
```

### Loops

```yaml
- name: Install multiple packages
  apt:
    name: "{{ item }}"
    state: present
  loop:
    - nginx
    - git
    - curl
    - vim

# With list variable
- name: Create users
  user:
    name: "{{ item.name }}"
    state: present
  loop: "{{ users }}"

# users defined as:
# users:
#   - name: alice
#   - name: bob
#   - name: charlie
```

### Blocks and Error Handling

```yaml
- name: Deploy application
  hosts: all
  tasks:
    - block:
        - name: Install dependencies
          apt:
            name: "{{ app_dependencies }}"

        - name: Build application
          command: ./build.sh

        - name: Deploy
          command: ./deploy.sh
      rescue:
        - name: Notify of failure
          telegram:
            token: "{{ telegram_token }}"
            chat_id: "{{ chat_id }}"
            message: "Deployment failed on {{ ansible_hostname }}"

        - name: Rollback
          command: ./rollback.sh

      always:
        - name: Cleanup
          command: ./cleanup.sh
```

---

## Lab 1.16: Single VM Configuration

### Configure Your Azure VM with Ansible

```yaml
# ~/ansible/azure-config.yml
---
- name: Configure Azure VM
  hosts: production
  become: true
  gather_facts: true

  vars:
    app_name: myapp
    app_user: azureuser

  pre_tasks:
    - name: Check connection
      ping:

  tasks:
    # System Updates
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600
      when: ansible_os_family == "Debian"

    - name: Upgrade all packages
      apt:
        upgrade: dist
      when: ansible_os_family == "Debian"

    # Install Common Tools
    - name: Install system packages
      apt:
        name:
          - curl
          - git
          - vim
          - htop
          - unzip
          - ca-certificates
          - apt-transport-https
          - software-properties-common
        state: present

    # Create Application User
    - name: Create application user
      user:
        name: "{{ app_user }}"
        groups: sudo
        append: yes
        shell: /bin/bash
        state: present

    # Configure SSH for App User
    - name: Create .ssh directory
      file:
        path: /home/{{ app_user }}/.ssh
        state: directory
        mode: '0700'
        owner: "{{ app_user }}"
        group: "{{ app_user }}"

    - name: Add authorized SSH key
      authorized_key:
        user: "{{ app_user }}"
        key: "{{ lookup('file', '~/.ssh/azure-vm-key.pub') }}"
        state: present

    # Create Application Directory
    - name: Create application directory
      file:
        path: /opt/{{ app_name }}
        state: directory
        mode: '0755'
        owner: "{{ app_user }}"
        group: "{{ app_user }}"

    # Configure Firewall (UFW)
    - name: Install UFW
      apt:
        name: ufw
        state: present

    - name: Allow SSH
      ufw:
        rule: allow
        name: OpenSSH

    - name: Allow HTTP
      ufw:
        rule: allow
        port: '80'
        proto: tcp

    - name: Enable UFW
      ufw:
        state: enabled
        policy: deny

    # Install Docker (optional)
    - name: Install Docker dependencies
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - gnupg
          - lsb-release
        state: present

    - name: Add Docker GPG key
      apt_key:
        url: https://download.docker.com/linux/ubuntu/gpg
        state: present

    - name: Add Docker repository
      apt_repository:
        repo: deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable
        state: present

    - name: Install Docker
      apt:
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
        state: present

    - name: Add user to docker group
      user:
        name: "{{ app_user }}"
        groups: docker
        append: yes

  handlers:
    - name: Restart docker
      service:
        name: docker
        state: restarted
```

### Run the Single VM Configuration

```bash
# First, test connection
ansible production -m ping

# Syntax check
ansible-playbook azure-config.yml --syntax-check

# Check mode (dry run)
ansible-playbook azure-config.yml --check

# Run for real
ansible-playbook azure-config.yml
```

---

## Lab 1.17: Multi-Node Management

### Multi-Tier Architecture Inventory

Managing multiple servers is where Ansible shines. Here's an inventory for a 3-tier architecture:

```yaml
# ~/ansible/inventory/production.yml
---
# All servers
all:
  children:
    # Web tier
    webservers:
      hosts:
        web1.prod.example.com:
          ansible_host: 10.0.1.10
        web2.prod.example.com:
          ansible_host: 10.0.1.11
        web3.prod.example.com:
          ansible_host: 10.0.1.12
      vars:
        app_tier: web
        nginx_sites:
          - default
          - api

    # Application tier
    appservers:
      hosts:
        api1.prod.example.com:
          ansible_host: 10.0.2.10
        api2.prod.example.com:
          ansible_host: 10.0.2.11
      vars:
        app_tier: api
        node_version: "20.x"

    # Database tier
    dbservers:
      hosts:
        db1.prod.example.com:
          ansible_host: 10.0.3.10
          db_role: primary
        db2.prod.example.com:
          ansible_host: 10.0.3.11
          db_role: replica
      vars:
        app_tier: db
        postgresql_version: 15

    # Cache/Redis tier
    cacheservers:
      hosts:
        cache1.prod.example.com:
          ansible_host: 10.0.4.10
      vars:
        redis_mode: standalone

    # Load balancer tier
    loadbalancers:
      hosts:
        lb1.prod.example.com:
          ansible_host: 10.0.0.10
        lb2.prod.example.com:
          ansible_host: 10.0.0.11
      vars:
        haproxy_stats_port: 8404

    # Cross-tier variables
  vars:
    environment: production
    domain: prod.example.com
    ntp_servers:
      - 0.pool.ntp.org
      - 1.pool.ntp.org
```

### Multi-Tier Playbook

```yaml
# ~/ansible/site.yml
---
# Site-wide playbook that orchestrates all tiers

# 1. Common configuration for ALL servers
- name: Apply common configuration to all hosts
  hosts: all
  become: true
  gather_facts: true
  tags: always

  vars:
    common_packages:
      - curl
      - git
      - vim
      - htop
      - unzip
      - ca-certificates
      - wget
      - rsync

  tasks:
    - name: Install common packages
      apt:
        name: "{{ common_packages }}"
        state: present
        update_cache: yes

    - name: Configure timezone
      community.general.timezone:
        name: UTC

    - name: Configure NTP
      apt:
        name: chrony
        state: present

    - name: Ensure NTP is running
      service:
        name: chrony
        state: started
        enabled: yes

    - name: Set hostname
      ansible.builtin.hostname:
        name: "{{ ansible_hostname }}"
      when: ansible_hostname != inventory_hostname

    - name: Add hosts file entries
      ansible.builtin.lineinfile:
        path: /etc/hosts
        line: "{{ item.ip }} {{ item.hostname }}"
        state: present
      loop:
        - ip: 10.0.0.10
          hostname: lb1.prod.example.com
        - ip: 10.0.1.10
          hostname: web1.prod.example.com

# 2. Web tier configuration
- name: Configure web servers
  hosts: webservers
  become: true
  gather_facts: true
  tags: web

  vars:
    nginx_config_path: /etc/nginx/sites-available

  tasks:
    - name: Install nginx
      apt:
        name: nginx
        state: present

    - name: Create nginx site config
      template:
        src: templates/nginx_site.conf.j2
        dest: "{{ nginx_config_path }}/{{ item }}.conf"
        mode: '0644'
      loop: "{{ nginx_sites }}"
      notify: Reload nginx

    - name: Enable nginx sites
      file:
        src: "{{ nginx_config_path }}/{{ item }}.conf"
        dest: /etc/nginx/sites-enabled/{{ item }}.conf
        state: link
      loop: "{{ nginx_sites }}"

    - name: Disable default site
      file:
        path: /etc/nginx/sites-enabled/default
        state: absent

    - name: Ensure nginx is running
      service:
        name: nginx
        state: started
        enabled: yes

  handlers:
    - name: Reload nginx
      service:
        name: nginx
        state: reloaded

    - name: Restart nginx
      service:
        name: nginx
        state: restarted

# 3. Application tier configuration
- name: Configure application servers
  hosts: appservers
  become: true
  gather_facts: true
  tags: app

  vars:
    app_dir: /opt/myapp
    node_user: nodeapp

  tasks:
    - name: Create application user
      user:
        name: "{{ node_user }}"
        shell: /bin/bash
        home: "{{ app_dir }}"
        state: present

    - name: Install Node.js
      ansible.builtin.get_url:
        url: "https://deb.nodesource.com/setup_{{ node_version }}"
        dest: /tmp/setup_node.sh
        mode: '0755'

    - name: Run Node.js setup
      command: /tmp/setup_node.sh
      args:
        creates: /usr/bin/node

    - name: Install Node.js packages
      apt:
        name: nodejs
        state: present

    - name: Create application directory
      file:
        path: "{{ app_dir }}"
        state: directory
        owner: "{{ node_user }}"
        group: "{{ node_user }}"
        mode: '0755'

    - name: Clone application repository
      git:
        repo: https://github.com/example/myapp.git
        dest: "{{ app_dir }}/current"
        version: main
        update: yes
        force: yes
      become_user: "{{ node_user }}"

    - name: Install npm dependencies
      community.general.npm:
        path: "{{ app_dir }}/current"
        state: present
      become_user: "{{ node_user }}"

    - name: Create systemd service
      template:
        src: templates/myapp.service.j2
        dest: /etc/systemd/system/myapp.service
        mode: '0644'
      notify: Restart myapp

    - name: Ensure myapp is running
      service:
        name: myapp
        state: started
        enabled: yes

  handlers:
    - name: Restart myapp
      service:
        name: myapp
        state: restarted

# 4. Database tier configuration
- name: Configure database servers
  hosts: dbservers
  become: true
  gather_facts: true
  tags: db

  vars:
    pg_packages:
      - postgresql-{{ postgresql_version }}
      - postgresql-contrib-{{ postgresql_version }}

  tasks:
    - name: Add PostgreSQL repository
      apt_repository:
        repo: "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main"
        state: present
        filename: pgdg

    - name: Add PostgreSQL GPG key
      apt_key:
        url: https://www.postgresql.org/media/keys/ACCC4CF8.asc
        state: present

    - name: Install PostgreSQL
      apt:
        name: "{{ pg_packages }}"
        state: present
        update_cache: yes

    - name: Ensure PostgreSQL is running
      service:
        name: postgresql
        state: started
        enabled: yes

    - name: Create database
      community.postgresql.postgresql_db:
        name: myapp_db
        encoding: UTF-8
        lc_collate: en_US.UTF-8
        lc_ctype: en_US.UTF-8
        template: template0
        state: present

    - name: Create database user
      community.postgresql.postgresql_user:
        name: appuser
        password: "{{ db_password | password_hash('sha256') }}"
        db: myapp_db
        priv: ALL
        state: present

    - name: Configure pg_hba.conf for internal network
      postgresql_pg_hba:
        dest: /etc/postgresql/{{ postgresql_version }}/main/pg_hba.conf
        contype: host
        database: myapp_db
        user: appuser
        address: 10.0.0.0/16
        method: md5
        state: present

    - name: Configure PostgreSQL to listen on all interfaces
      postgresql_set:
        name: listen_addresses
        value: '*'
        db: postgres
      restart_possible: yes

  handlers:
    - name: Restart postgresql
      service:
        name: postgresql
        state: restarted

# 5. Load balancer tier configuration
- name: Configure load balancers
  hosts: loadbalancers
  become: true
  gather_facts: true
  tags: lb

  tasks:
    - name: Install HAProxy
      apt:
        name: haproxy
        state: present

    - name: Configure HAProxy
      template:
        src: templates/haproxy.cfg.j2
        dest: /etc/haproxy/haproxy.cfg
        mode: '0644'
      notify: Restart haproxy

    - name: Enable HAProxy stats
      lineinfile:
        path: /etc/haproxy/haproxy.cfg
        line: "stats bind-process 1"
        state: present

    - name: Ensure HAProxy is running
      service:
        name: haproxy
        state: started
        enabled: yes

  handlers:
    - name: Restart haproxy
      service:
        name: haproxy
        state: restarted
```

### Multi-Tier Variables

```yaml
# ~/ansible/group_vars/webservers.yml
---
nginx_sites:
  - default
  - api
nginx_worker_connections: 4096
nginx_client_max_body_size: "50M"

# ~/ansible/group_vars/dbservers.yml
---
postgresql_version: 15
postgresql_pg_hba_conf:
  - type: host
    database: all
    user: all
    address: 10.0.0.0/16
    method: md5

# ~/ansible/group_vars/loadbalancers.yml
---
haproxy_stats_port: 8404
haproxy_stats_bind: "0.0.0.0"
haproxy_mode: http
```

### Rolling Updates with Serial

```yaml
# ~/ansible/rolling-update.yml
---
- name: Rolling update web servers
  hosts: webservers
  become: true
  serial: 1  # Update one host at a time

  vars:
    deploy_user: deploy
    deploy_dir: /opt/myapp

  tasks:
    - name: Take server out of load balancer
      ansible.builtin.set_fact:
        server_out: true

    - name: Wait for connections to drain
      ansible.builtin.wait_for:
        host: "{{ ansible_default_ipv4.address }}"
        port: 443
        state: drained
        timeout: 300

    - name: Deploy new version
      git:
        repo: https://github.com/example/myapp.git
        dest: "{{ deploy_dir }}/current"
        version: main
        update: yes
        force: yes
      become_user: "{{ deploy_user }}"

    - name: Restart application
      systemd:
        name: myapp
        state: restarted
      become_user: root

    - name: Wait for application to be healthy
      ansible.builtin.uri:
        url: "http://localhost/health"
        status_code: 200
      register: health_check
      until: health_check.status == 200
      retries: 30
      delay: 2

    - name: Put server back in load balancer
      ansible.builtin.set_fact:
        server_out: false
```

### Parallel Execution Control

```yaml
# Control execution strategy
- name: Deploy with forks
  hosts: webservers
  become: true
  strategy: free  # All hosts run as fast as possible

  tasks:
    - name: Install packages
      apt:
        name: "{{ item }}"
        state: latest
      loop: "{{ packages }}"
      throttle: 5  # Limit concurrent tasks

# Use serial for controlled rollout
- name: Deploy with serial control
  hosts: webservers
  become: true
  serial:
    - 1           # First batch: 1 host
    - 3           # Second batch: 3 hosts
    - 10          # Third batch: 10 hosts
  max_fail_percentage: 10  # Stop if >10% fail

  tasks:
    - name: Deploy
      command: /opt/scripts/deploy.sh
```

### Ad-Hoc Commands for Multi-Node

```bash
# Check all web servers
ansible webservers -m ping

# Check memory on all app servers
ansible appservers -a "free -h"

# Get uptime from all database servers
ansible dbservers -a "uptime"

# Copy file to all web servers
ansible webservers -m copy -a "src=/tmp/config.yml dest=/opt/config.yml"

# Restart service on all load balancers
ansible loadbalancers -m systemd -a "name=haproxy state=restarted"

# Gather facts from all hosts
ansible all -m setup -a "filter=ansible_memory_mb"

# Check disk usage across all servers
ansible all -a "df -h"

# Run security updates on all servers
ansible all -b -m apt -a "upgrade=dist update_cache=yes"

# Check service status on all nodes
ansible all -m service_facts

# Get ansible_facts for all hosts
ansible all -m setup | grep -E "(ansible_distribution|ansible_hostname)"
```

---

## Lab 1.18: Ansible with Azure Managed Identity

### Authenticate to Azure Using Managed Identity

```yaml
# ~/ansible/azure-cloud.yml
---
- name: Configure Azure Resources with MI
  hosts: localhost
  connection: local
  gather_facts: no

  collections:
    - azure.azcollection

  vars:
    resource_group: rg-devops-learn
    location: eastus
    vm_name: devops-vm

  tasks:
    - name: Get Azure VM info using Managed Identity
      azure_rm_virtualmachine_info:
        resource_group: "{{ resource_group }}"
        name: "{{ vm_name }}"
      register: vm_info

    - name: Display VM information
      debug:
        msg: |
          VM Name: {{ vm_info.vms[0].name }}
          State: {{ vm_info.vms[0].powerstate }}
          Size: {{ vm_info.vms[0].size }}
          Public IP: {{ vm_info.vms[0].public_ip }}

    - name: Start Azure VM
      azure_rm_virtualmachine:
        resource_group: "{{ resource_group }}"
        name: "{{ vm_name }}"
        started: yes

    - name: Stop Azure VM
      azure_rm_virtualmachine:
        resource_group: "{{ resource_group }}"
        name: "{{ vm_name }}"
        started: no
```

### Azure Resource Management Playbook

```yaml
# ~/ansible/azure-resources.yml
---
- name: Azure Infrastructure Management
  hosts: localhost
  connection: local
  gather_facts: no

  vars:
    project: devops
    environment: dev
    location: eastus
    resource_group: "rg-{{ project }}-{{ environment }}"

  tasks:
    - name: Create Resource Group
      azure_rm_resourcegroup:
        name: "{{ resource_group }}"
        location: "{{ location }}"
        tags:
          Environment: "{{ environment }}"
          Project: "{{ project }}"
          ManagedBy: Ansible
      register: rg

    - name: Create Virtual Network
      azure_rm_virtualnetwork:
        resource_group: "{{ resource_group }}"
        name: "vnet-{{ project }}-{{ environment }}"
        address_prefixes: "10.0.0.0/16"

    - name: Create Subnet
      azure_rm_subnet:
        resource_group: "{{ resource_group }}"
        name: "subnet-app"
        virtual_network_name: "vnet-{{ project }}-{{ environment }}"
        address_prefix: "10.0.1.0/24"

    - name: Create Network Security Group
      azure_rm_securitygroup:
        resource_group: "{{ resource_group }}"
        name: "nsg-{{ project }}-{{ environment }}"
        rules:
          - name: SSH
            protocol: Tcp
            destination_port_range: 22
            access: Allow
            priority: 100
            direction: Inbound
          - name: HTTP
            protocol: Tcp
            destination_port_range: 80
            access: Allow
            priority: 101
            direction: Inbound

    - name: Create Public IP
      azure_rm_publicipaddress:
        resource_group: "{{ resource_group }}"
        name: "pip-{{ project }}-{{ environment }}"
        allocation_method: Dynamic
```

### Run Azure Playbook

```bash
# Install Azure collection
ansible-galaxy collection install azure.azcollection

# Run with Azure CLI authentication (uses MI on Azure VM)
az login
ansible-playbook azure-resources.yml

# On Azure VM, MI is automatic
ansible-playbook azure-resources.yml
```

---

## Production Ansible Project Structure

```
~/ansible/
├── ansible.cfg              # Ansible configuration
├── inventory/               # Inventory files
│   ├── production.yml
│   ├── staging.yml
│   └── development.yml
├── group_vars/              # Group variables
│   ├── all.yml
│   ├── production.yml
│   └── webservers.yml
├── host_vars/               # Host variables
│   ├── web1.example.com.yml
│   └── db1.example.com.yml
├── roles/                   # Reusable roles
│   ├── common/
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   ├── handlers/
│   │   │   └── main.yml
│   │   ├── templates/
│   │   └── files/
│   ├── nginx/
│   │   ├── tasks/
│   │   ├── handlers/
│   │   └── templates/
│   └── docker/
│       ├── tasks/
│       └── handlers/
├── playbooks/               # Playbook files
│   ├── site.yml
│   ├── web.yml
│   └── db.yml
└── requirements.yml         # Role dependencies
```

---

## Interview Reinforcement

### Q: What's the difference between Ansible and bash scripts?

> "Bash scripts are imperative - you specify each step. Ansible is declarative - you specify the desired state, and Ansible figures out how to get there. Ansible is idempotent by default; running it multiple times produces the same result. Bash requires manual handling of idempotency and state tracking."

### Q: How does Ansible ensure idempotency?

> "Ansible modules check the current state before making changes. If a file exists with correct content, the `copy` module won't overwrite it. If a service is already running, the `service` module won't restart it. This built-in behavior ensures playbooks can be run safely multiple times."

### Q: What's the difference between `command` and `shell` modules?

> "The `command` module executes commands directly without a shell, so shell features like pipes, redirects, and environment variables don't work. The `shell` module runs through the shell, supporting all shell features. For most cases, `command` is preferred for security and predictability."

### Q: When would you use handlers?

> "Handlers are triggered tasks that run only when notified. They're ideal for actions that should only happen when something changes, like restarting a service after config changes. This avoids unnecessary restarts if the config is already correct."

### Q: How do you manage sensitive data in Ansible?

> "I use Ansible Vault for encrypting sensitive files like passwords and API keys. Variables can be encrypted at file or variable level. I never commit secrets to version control - they're decrypted at runtime using a password file or script."

### Q: How does Ansible authenticate to Azure VMs?

> "I use SSH key-based authentication. For Azure, I generate an SSH key pair, deploy it to VMs, and reference the private key in the inventory. On Azure VMs, I can also use Azure Managed Identity for Azure API operations, avoiding credentials entirely."

---

## Quick Reference

```bash
# Installation
pip install ansible

# Inventory
ansible-inventory -i inventory --list

# Ping all hosts
ansible all -m ping

# Run playbook
ansible-playbook site.yml

# Syntax check
ansible-playbook site.yml --syntax-check

# Check mode (dry run)
ansible-playbook site.yml --check

# Limit to host/group
ansible-playbook site.yml --limit web1

# Verbose output
ansible-playbook site.yml -v
ansible-playbook site.yml -vvv

# Gather facts
ansible all -m setup

# Install role from Galaxy
ansible-galaxy install geerlingguy.docker
```

---

## Professional Deliverables

| Deliverable | Description | Location |
|-------------|-------------|----------|
| Ansible installed | Control node configured | `~/.ansible/` |
| Inventory | Host definitions | `~/ansible/inventory` |
| First playbook | Basic playbook | `~/ansible/first-playbook.yml` |
| Azure VM config | Production playbook | `~/ansible/azure-config.yml` |
| Azure resources | Azure management | `~/ansible/azure-resources.yml` |

---

## Phase 1 Complete Checklist

After completing Ansible section:

- [ ] Ansible installed on control node
- [ ] Inventory file created
- [ ] First playbook written and run
- [ ] Common modules used (file, apt, service, user)
- [ ] Variables and facts understood
- [ ] Handlers implemented
- [ ] Azure VM configured with Ansible
- [ ] Azure resource management playbook created

---

## Next Steps

After Phase 1 Ansible:

- **Phase 2**: Version control your Ansible playbooks with Git
- **Phase 3**: Use Azure Key Vault for Ansible secrets
- **Phase 4**: Define infrastructure with Terraform, configure with Ansible
- **Phase 5**: Integrate Ansible into CI/CD pipelines
- **Phase 6**: Configure container hosts with Ansible