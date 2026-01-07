# Phase 1: Linux Systems & Automation Guide

This guide covers Linux fundamentals, basic commands, shell scripting, and SSH hardening for production environments.

---

## Table of Contents

1. [Linux Basics](#linux-basics)
   - [Navigation & File Management](#navigation--file-management)
   - [File Permissions](#file-permissions)
   - [User Management](#user-management)
   - [Process Management](#process-management)
   - [Package Management](#package-management)
2. [Shell Scripting Fundamentals](#shell-scripting-fundamentals)
   - [Variables & Data Types](#variables--data-types)
   - [Control Flow](#control-flow)
   - [Functions](#functions)
   - [Error Handling](#error-handling)
3. [System Administration](#system-administration)
   - [Service Management (systemd)](#service-management-systemd)
   - [Log Management](#log-management)
   - [Disk & Memory Management](#disk--memory-management)
4. [SSH Hardening](#ssh-hardening)
   - [Security Configuration](#security-configuration)
   - [Automated Hardening Script](#automated-hardening-script)
5. [Professional Deliverables](#professional-deliverables)

---

## Linux Basics

### Navigation & File Management

```bash
# Current directory and path
pwd                  # Print working directory
ls                   # List files
ls -la               # List with details (including hidden)
ls -lh               # Human-readable sizes

# Change directory
cd /path/to/dir      # Go to absolute path
cd ./relative/path   # Go to relative path
cd ~                 # Go to home directory
cd -                 # Go to previous directory

# Create/remove files and directories
touch file.txt       # Create empty file
mkdir -p dir/subdir  # Create directory tree
rm file.txt          # Delete file
rm -r dir/           # Delete directory recursively
rm -rf dir/          # Force delete (dangerous!)

# Copy and move
cp source.txt dest.txt      # Copy file
cp -r src/ dest/            # Copy directory
mv old.txt new.txt          # Rename/move file

# View file contents
cat file.txt        # Print entire file
head -n 20 file.txt # First 20 lines
tail -f file.txt    # Follow file (for logs)
less file.txt       # Paginated view
grep "pattern" file.txt  # Search in file

# Find files
find /path -name "*.txt"   # Find by name
find /path -type f         # Find files only
find /path -mtime -7       # Modified in last 7 days

# Archive and compress
tar -czf archive.tar.gz dir/   # Create tar.gz
tar -xzf archive.tar.gz        # Extract tar.gz
zip -r archive.zip dir/        # Create zip
```

### File Permissions

```bash
# View permissions
ls -l file.txt
# Output: -rw-r--r-- 1 user group 1234 Dec 20 10:00 file.txt
#         ^  ^  ^  ^
#         |  |  |  └── Other (r=4, w=2, x=1)
#         |  |  └──── Group (r=4, w=2, x=1)
#         |  └────── Owner (r=4, w=2, x=1)
#         └───────── File type (-=file, d=directory, l=link)

# Permission codes
# rwx rwx rwx
# 421 421 421
# 7 = rwx (full)
# 6 = rw- (read/write)
# 5 = r-x (read/execute)
# 4 = r-- (read only)
# 0 = --- (none)

# Change permissions
chmod 755 file.txt      # rwxr-xr-x
chmod 644 file.txt      # rw-r--r--
chmod +x script.sh      # Add execute permission
chmod -R 700 dir/       # Recursive

# Change owner
chown user:group file.txt
chown -R user:group dir/
```

### User Management

```bash
# Current user
whoami          # Display current user
id              # Display user ID and groups
groups          # Display user's groups

# User management (requires sudo)
sudo adduser newuser           # Create new user
sudo userdel username          # Delete user
sudo passwd username           # Set user password

# Group management
groups username                # Show user's groups
sudo adduser username sudo     # Add user to sudo group
sudo usermod -aG group user    # Add user to group

# Switch user
su - username                  # Switch to user
sudo -i                       # Switch to root (login shell)
sudo su                       # Switch to root
```

### Process Management

```bash
# View processes
ps                     # Current shell processes
ps aux                 # All processes with details
ps aux | grep nginx    # Find specific process
top                    # Interactive process viewer
htop                   # Enhanced top (if installed)

# Process stats
pidof nginx            # Get PID of process
pgrep -l nginx         # Find processes by name

# Manage processes
kill PID               # Terminate process (graceful)
kill -9 PID            # Force kill
killall process_name   # Kill all instances
pkill -f "pattern"     # Kill by pattern

# Background jobs
command &              # Run in background
Ctrl+Z                 # Suspend current job
bg                     # Resume in background
fg                     # Bring to foreground
jobs                   # List background jobs

# System resources
df -h                  # Disk usage
du -sh dir/            # Directory size
free -h                # Memory usage
uptime                 # System uptime
```

### Package Management

**Ubuntu/Debian:**
```bash
sudo apt update              # Update package lists
sudo apt upgrade             # Upgrade packages
sudo apt install package     # Install package
sudo apt remove package      # Remove package
apt search package           # Search for package
dpkg -l                      # List installed packages
```

**RHEL/CentOS:**
```bash
sudo yum update              # Update packages
sudo yum install package     # Install package
sudo yum remove package      # Remove package
yum search package           # Search package
rpm -qa                      # List installed packages
```

---

## Shell Scripting Fundamentals

### Variables & Data Types

```bash
#!/bin/bash

# Variable assignment (NO spaces around =)
NAME="DevOps"
VERSION=1.0
IS_READY=true

# Using variables
echo "Name: $NAME"
echo "Version: ${VERSION}"

# Read-only variables
readonly CONSTANT="immutable"

# Arrays
FRUITS=("apple" "banana" "cherry")
echo "${FRUITS[0]}"       # First element
echo "${FRUITS[@]}"       # All elements
echo "${#FRUITS[@]}"      # Array length

# Associative arrays (Bash 4+)
declare -A USER
USER[name]="admin"
USER[email]="admin@example.com"

# Environment variables
export MY_VAR="value"     # Export to child processes
echo $HOME                # Use environment variable
```

### Control Flow

```bash
#!/bin/bash

# IF-ELSE
if [ $AGE -ge 18 ]; then
    echo "Adult"
elif [ $AGE -ge 13 ]; then
    echo "Teenager"
else
    echo "Child"
fi

# File conditions
if [ -f "file.txt" ]; then
    echo "File exists"
fi

if [ -d "/path" ]; then
    echo "Directory exists"
fi

if [ -z "$VAR" ]; then
    echo "Variable is empty"
fi

# CASE statement
case $OS in
    ubuntu)
        echo "Ubuntu detected"
        ;;
    centos|rhel)
        echo "Red Hat detected"
        ;;
    *)
        echo "Unknown OS"
        ;;
esac

# FOR loop
for i in {1..5}; do
    echo "Iteration: $i"
done

for file in *.txt; do
    echo "Processing: $file"
done

# WHILE loop
COUNTER=0
while [ $COUNTER -lt 5 ]; do
    echo "Count: $COUNTER"
    ((COUNTER++))
done

# UNTIL loop
until [ -f "/tmp/ready" ]; do
    echo "Waiting..."
    sleep 1
done
```

### Functions

```bash
#!/bin/bash

# Basic function
greet() {
    echo "Hello, $1!"
}

greet "World"    # Call with argument

# Function with return value
get_sum() {
    local result=$(( $1 + $2 ))
    echo $result
}

TOTAL=$(get_sum 10 20)
echo "Sum: $TOTAL"

# Function with multiple returns
get_stats() {
    echo "min=1 max=100 avg=50"
}

# Parse output
STATS=$(get_stats)
MIN=$(echo $STATS | cut -d' ' -f1 | cut -d'=' -f2)
MAX=$(echo $STATS | cut -d' ' -f2 | cut -d'=' -f2)

# Function with exit status
check_file() {
    if [ -f "$1" ]; then
        return 0  # Success
    else
        return 1  # Failure
    fi
}

if check_file "file.txt"; then
    echo "File exists"
else
    echo "File not found"
fi
```

### Error Handling

```bash
#!/bin/bash

# Exit on error (recommended for scripts)
set -euo pipefail

# Disable exit on error for specific commands
set +e
command_that_might_fail
set -e

# Trap errors
error_handler() {
    echo "Error on line $1"
    exit 1
}
trap 'error_handler $LINENO' ERR

# Check if command succeeded
if command; then
    echo "Success"
else
    echo "Failed"
fi

# Conditional execution
command1 && command2    # Run command2 if command1 succeeds
command1 || command2    # Run command2 if command1 fails

# Verify required arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <arg1> <arg2>"
    exit 1
fi

# Verify file exists before processing
if [ ! -f "input.txt" ]; then
    echo "Error: input.txt not found"
    exit 1
fi

# Logging function
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $level: $message"
}

log "INFO" "Script started"
log "ERROR" "Something failed"
```

### Practical Script Examples

**Example 1: System Health Check**
```bash
#!/bin/bash
# system-health-check.sh

set -euo pipefail

echo "=== System Health Check ==="
echo ""

# CPU Load
echo "CPU Load:"
uptime | awk '{print "  1min:", $NF}'

# Memory Usage
echo ""
echo "Memory Usage:"
free -h | grep Mem | awk '{print "  Used:", $3, "/ Total:", $2}'

# Disk Usage
echo ""
echo "Disk Usage:"
df -h | grep -E '^/dev/' | awk '{print " ", $1, ":", $5, "used"}'

# Top 5 CPU processes
echo ""
echo "Top 5 CPU Processes:"
ps aux --sort=-%cpu | head -6 | tail -5 | awk '{print " ", $2, $3, "% -", $11}'

# Running services
echo ""
echo "Running Services:"
systemctl list-units --type=service --state=running | grep -c ".service"
echo "  services running"

echo ""
echo "=== Health Check Complete ==="
```

**Example 2: Log File Analyzer**
```bash
#!/bin/bash
# log-analyzer.sh

set -euo pipefail

LOG_FILE="${1:-/var/log/syslog}"

if [ ! -f "$LOG_FILE" ]; then
    echo "Error: Log file not found: $LOG_FILE"
    exit 1
fi

echo "=== Log Analysis: $LOG_FILE ==="
echo ""

# Line count
echo "Total lines: $(wc -l < "$LOG_FILE")"

# Error count
ERRORS=$(grep -c "ERROR" "$LOG_FILE" 2>/dev/null || echo 0)
echo "ERROR entries: $ERRORS"

# Warning count
WARNINGS=$(grep -c "WARNING" "$LOG_FILE" 2>/dev/null || echo 0)
echo "WARNING entries: $WARNINGS"

# Last 10 entries
echo ""
echo "Last 10 entries:"
tail -10 "$LOG_FILE"

# Search for errors in last hour
echo ""
echo "Recent errors (last hour):"
grep "ERROR" "$LOG_FILE" | tail -5
```

**Example 3: Backup Script**
```bash
#!/bin/bash
# backup.sh

set -euo pipefail

# Configuration
SOURCE_DIR="${1:-/home/user/data}"
BACKUP_DIR="/var/backup"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backup_${DATE}.tar.gz"

# Create backup directory if not exists
mkdir -p "$BACKUP_DIR"

# Create backup
echo "Creating backup of $SOURCE_DIR..."
tar -czf "$BACKUP_DIR/$BACKUP_FILE" "$SOURCE_DIR"

# Verify backup
if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
    echo "[SUCCESS] Backup created: $BACKUP_FILE ($SIZE)"
else
    echo "[ERROR] Backup failed!"
    exit 1
fi

# Remove backups older than 7 days
echo "Cleaning up old backups..."
find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +7 -delete

echo "Backup complete!"
```

---

## System Administration

### Service Management (systemd)

```bash
# View services
systemctl list-units --type=service          # List running services
systemctl list-units --type=service --all    # List all services
systemctl status servicename                 # Service status

# Manage services
sudo systemctl start servicename             # Start service
sudo systemctl stop servicename              # Stop service
sudo systemctl restart servicename           # Restart service
sudo systemctl reload servicename            # Reload config
sudo systemctl enable servicename            # Enable at boot
sudo systemctl disable servicename           # Disable at boot

# Check if service is active
systemctl is-active nginx                    # returns "active" or "inactive"
systemctl is-enabled nginx                   # returns "enabled" or "disabled"

# View service logs
journalctl -u servicename                    # Service logs
journalctl -u servicename -f                 # Follow logs
journalctl -u servicename --since "1 hour ago"
journalctl --disk-usage                      # Log disk usage
journalctl --vacuum-time=7d                  # Clean old logs
```

### Log Management

```bash
# Important log locations
/var/log/syslog          # System logs (Ubuntu)
/var/log/messages        # System logs (RHEL/CentOS)
/var/log/auth.log        # Authentication logs
/var/log/nginx/access.log  # Nginx access
/var/log/nginx/error.log   # Nginx errors
/var/log/apache2/        # Apache logs

# View logs
tail -f /var/log/syslog              # Follow live
grep "error" /var/log/syslog | tail  # Search errors
less /var/log/syslog                 # Interactive view

# Log rotation
cat /etc/logrotate.conf              # Main config
ls /etc/logrotate.d/                 # Service-specific configs

# Journalctl examples
journalctl -p err                    # Filter by priority
journalctl -k                        # Kernel messages
journalctl --boot=-1                 # Previous boot
journalctl -u nginx --since yesterday
```

### Disk & Memory Management

```bash
# Disk usage
df -h                        # All mounted filesystems
df -h /home                  # Specific mount
du -sh /var/log              # Directory size
du -h --max-depth=1 /        # Top-level sizes

# Inode usage
df -i                        # Inode information

# Memory usage
free -h                      # Memory and swap
cat /proc/meminfo            # Detailed memory info

# Process memory
ps aux --sort=-%mem | head   # Sort by memory
pmap PID                     # Process memory map

# Swappiness
cat /proc/sys/vm/swappiness  # Current swappiness
sudo sysctl vm.swappiness=10 # Set swappiness
```

---

## SSH Hardening

### Security Configuration

See `02-ssh-hardening-guide.md` for detailed SSH hardening steps.

### Automated Hardening Script

Run the automated script:

```bash
# Upload and run
scp scripts/common/01-ssh-hardening.sh azureuser@$VM_IP:~/
ssh azureuser@$VM_IP "chmod +x ~/01-ssh-hardening.sh && sudo ~/01-ssh-hardening.sh"
```

**Expected outcome:**
```bash
sudo sshd -T | grep -E 'passwordauthentication|permitrootlogin'
# passwordauthentication no
# permitrootlogin no
```

---

## Professional Deliverables

Complete Phase 1 by creating these artifacts:

| Deliverable | Description | Location |
|-------------|-------------|----------|
| Hardened VM | SSH hardened Azure VM | Azure Portal |
| Health Check Script | `system-health-check.sh` | `scripts/` |
| Backup Script | `backup.sh` | `scripts/` |
| Log Analyzer | `log-analyzer.sh` | `scripts/` |
| SSH Hardening Script | `01-ssh-hardening.sh` | `scripts/` |
| Runbook | Documented procedures | `docs/` |

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `ls -la` | List files with details |
| `chmod 755 file` | Set permissions |
| `ps aux` | View all processes |
| `top` | Interactive process monitor |
| `df -h` | Disk usage |
| `free -h` | Memory usage |
| `systemctl status` | Service status |
| `journalctl -u svc` | Service logs |
| `tail -f` | Follow file |

---

## Interview Reinforcement

**Q: How do you troubleshoot high CPU usage on a Linux server?**
> "I'd use `top` to identify the process, then `ps aux | grep <pid>` for details. If it's a known process, check its logs and configuration. For unknown processes, investigate the binary location and research online."

**Q: Explain the difference between systemd and init.**
> "Systemd is the modern init system that manages services in parallel (faster boot), uses unit files for configuration, and provides built-in logging with journalctl. Traditional init uses sequential startup with SysV scripts."

**Q: How do you handle a script that might fail?**
> "I use `set -euo pipefail` for strict error handling. I check exit codes with `$?` or `if command; then`. I use `trap` for cleanup on errors and validate inputs before processing."

**Q: What's the difference between soft and hard links?**
> "Hard links point directly to the inode (same file, multiple names). Soft links are separate files pointing to the path. Hard links can't cross filesystems; soft links can be broken if the target moves."

**Q: How would you secure a Linux server?**
> "Disable password auth, enforce key-based SSH only, disable root login, set idle timeouts, keep packages updated, configure firewall (ufw/iptables), enable automatic security updates, and regularly audit logs."
