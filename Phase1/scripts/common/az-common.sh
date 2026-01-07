#!/bin/bash
# Azure Common Functions Library
# Source this file in other scripts: source ./az-common.sh

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Azure CLI is installed
check_az_cli() {
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed."
        echo ""
        echo "Install Azure CLI:"
        echo "  macOS: brew install azure-cli"
        echo "  Linux: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
        echo "  Windows: winget install Microsoft.AzureCLI"
        echo ""
        echo "Or visit: https://docs.microsoft.com/cli/azure/install-azure-cli"
        return 1
    fi
    return 0
}

# Check if logged into Azure
check_az_login() {
    if ! az account show &>/dev/null; then
        log_error "Not logged into Azure."
        echo ""
        echo "Please login:"
        echo "  az login"
        echo ""
        echo "Or use service principal (for CI/CD):"
        echo "  az login --service-principal -u <app-id> -p <password> --tenant <tenant-id>"
        return 1
    fi
    return 0
}

# Validate Azure location
validate_location() {
    local location=$1

    if ! az account list-locations --query "[?name=='$location'].name" -o tsv &>/dev/null; then
        log_error "Invalid Azure location: $location"
        echo ""
        echo "Common locations:"
        az account list-locations --query "[?contains(name, 'us') || contains(name, 'eu')].name" -o tsv | head -10
        echo ""
        echo "List all locations: az account list-locations -o table"
        return 1
    fi
    return 0
}

# Check if resource group exists
resource_group_exists() {
    local rg_name=$1
    az group show --name "$rg_name" &>/dev/null
    return $?
}

# Check if VM exists
vm_exists() {
    local rg_name=$1
    local vm_name=$2
    az vm show --resource-group "$rg_name" --name "$vm_name" &>/dev/null
    return $?
}

# Find or create SSH key
find_or_create_ssh_key() {
    local key_path=$1

    # Check if key pair exists
    if [ -f "$key_path" ] && [ -f "${key_path}.pub" ]; then
        echo "$key_path"
        return 0
    fi

    # Try common default keys
    local default_keys=("id_ed25519" "id_rsa" "id_ecdsa")
    for key in "${default_keys[@]}"; do
        local default_path="$HOME/.ssh/$key"
        if [ -f "$default_path" ] && [ -f "${default_path}.pub" ]; then
            echo "$default_path"
            return 0
        fi
    done

    # Check if .ssh directory exists
    if [ ! -d "$HOME/.ssh" ]; then
        mkdir -p "$HOME/.ssh" 2>/dev/null || return 1
        chmod 700 "$HOME/.ssh" 2>/dev/null || true
    fi

    # Create new key
    if ssh-keygen -t ed25519 -f "$key_path" -N "" -q 2>/dev/null; then
        chmod 600 "$key_path" 2>/dev/null || true
        chmod 644 "${key_path}.pub" 2>/dev/null || true
        echo "$key_path"
        return 0
    else
        return 1
    fi
}

# Wait for VM to be ready
wait_for_vm() {
    local rg_name=$1
    local vm_name=$2
    local max_wait=${3:-300}  # Default 5 minutes
    local elapsed=0

    log_info "Waiting for VM $vm_name to be ready..."

    while [ $elapsed -lt $max_wait ]; do
        if vm_exists "$rg_name" "$vm_name"; then
            local power_state
            power_state=$(az vm get-instance-view --resource-group "$rg_name" --name "$vm_name" --query "instanceView.statuses[?code=='PowerState/running'].code" -o tsv 2>/dev/null)

            if [ -n "$power_state" ]; then
                log_success "VM $vm_name is ready"
                return 0
            fi
        fi

        sleep 5
        elapsed=$((elapsed + 5))
        echo -n "."
    done

    echo ""
    log_warning "VM $vm_name may still be provisioning (continuing anyway)"
    return 0
}

# Wait for SSH to be ready on VM
wait_for_ssh() {
    local ssh_key=$1
    local admin_user=$2
    local public_ip=$3
    local max_wait=${4:-180}  # Default 3 minutes
    local elapsed=0

    log_info "Waiting for SSH to be ready on ${public_ip}..."

    while [ $elapsed -lt $max_wait ]; do
        if ssh -i "$ssh_key" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            -o BatchMode=yes -o "ServerAliveInterval=5" -o "ServerAliveCountMax=1" \
            "${admin_user}@${public_ip}" "echo 'SSH ready'" >/dev/null 2>&1; then
            log_success "SSH is ready"
            return 0
        fi

        sleep 5
        elapsed=$((elapsed + 5))
        echo -n "."
    done

    echo ""
    log_error "SSH did not become ready within ${max_wait} seconds"
    return 1
}

# Wait for cloud-init to complete
wait_for_cloud_init() {
    local ssh_key=$1
    local admin_user=$2
    local public_ip=$3
    local max_wait=${4:-180}  # Default 3 minutes
    local elapsed=0

    log_info "Waiting for cloud-init to complete..."

    while [ $elapsed -lt $max_wait ]; do
        if ssh -i "$ssh_key" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            -o BatchMode=yes "${admin_user}@${public_ip}" \
            "test -f /var/lib/cloud/instance/boot-finished 2>/dev/null || echo 'pending'" >/dev/null 2>&1; then
            log_success "Cloud-init completed"
            return 0
        fi

        sleep 5
        elapsed=$((elapsed + 5))
        echo -n "."
    done

    echo ""
    log_warning "Cloud-init may still be running (continuing anyway)"
    return 0
}

# Get public IP of VM
get_vm_public_ip() {
    local rg_name=$1
    local vm_name=$2

    az vm show \
        --resource-group "$rg_name" \
        --name "$vm_name" \
        --show-details \
        --query "publicIps" \
        --output tsv 2>/dev/null
}

# Confirm action with user
confirm_action() {
    local message=$1
    local default=${2:-no}

    if [ "${AZURE_DO_NOT_PROMPT:-}" = "true" ]; then
        return 0
    fi

    local prompt
    if [ "$default" = "yes" ]; then
        prompt="$message [Y/n]: "
    else
        prompt="$message [y/N]: "
    fi

    read -p "$prompt" response
    response=${response:-$default}

    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Check prerequisites
check_prerequisites() {
    local errors=0

    if ! check_az_cli; then
        errors=$((errors + 1))
    fi

    if ! check_az_login; then
        errors=$((errors + 1))
    fi

    return $errors
}

# Display script header
display_header() {
    local title=$1
    echo ""
    echo "=========================================="
    echo "  $title"
    echo "=========================================="
    echo ""
}

# Display resource summary
display_resource_summary() {
    local rg_name=$1
    local location=${2:-}

    echo ""
    echo "Resource Summary:"
    echo "  Resource Group: $rg_name"

    if [ -n "$location" ]; then
        echo "  Location: $location"
    fi

    if resource_group_exists "$rg_name"; then
        local vm_count
        vm_count=$(az vm list --resource-group "$rg_name" --query "length(@)" -o tsv 2>/dev/null || echo "0")
        echo "  VMs: $vm_count"
    fi
    echo ""
}

# Run script on remote VM
run_script_on_vm() {
    local ssh_key=$1
    local admin_user=$2
    public_ip=$3
    local script_path=$4
    local timeout_duration=${5:-600}  # Default 10 minutes

    if [ ! -f "$script_path" ]; then
        log_error "Script not found: $script_path"
        return 1
    fi

    log_info "Running script on VM: $(basename "$script_path")"

    # Check if timeout command is available (not on macOS by default)
    if command -v timeout &> /dev/null; then
        # Use timeout if available
        if timeout "$timeout_duration" ssh -i "$ssh_key" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
            -o "ServerAliveInterval=15" -o "ServerAliveCountMax=3" \
            "${admin_user}@${public_ip}" \
            "bash -s" < "$script_path"; then
            log_success "Script executed successfully"
            return 0
        else
            local exit_code=$?
            if [ $exit_code -eq 124 ]; then
                log_error "Script execution timed out after ${timeout_duration} seconds"
            else
                log_error "Script execution failed with exit code $exit_code"
            fi
            return 1
        fi
    else
        # Fallback: run without timeout command (macOS)
        log_warning "timeout command not available, running without timeout..."
        if ssh -i "$ssh_key" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
            -o "ServerAliveInterval=15" -o "ServerAliveCountMax=3" \
            "${admin_user}@${public_ip}" \
            "bash -s" < "$script_path"; then
            log_success "Script executed successfully"
            return 0
        else
            local exit_code=$?
            log_error "Script execution failed with exit code $exit_code"
            return 1
        fi
    fi
}

# Verify LazyVim installation on remote VM
verify_lazyvim_installation() {
    local ssh_key=$1
    local admin_user=$2
    local public_ip=$3

    log_info "Verifying LazyVim installation..."

    # Check if nvim is installed
    if ! ssh -i "$ssh_key" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        "${admin_user}@${public_ip}" "command -v nvim" >/dev/null 2>&1; then
        log_error "Neovim not found on VM"
        return 1
    fi

    # Check if LazyVim config exists
    if ! ssh -i "$ssh_key" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        "${admin_user}@${public_ip}" "test -d ~/.config/nvim" >/dev/null 2>&1; then
        log_error "LazyVim configuration not found"
        return 1
    fi

    # Check if plugins were installed
    local plugin_count
    plugin_count=$(ssh -i "$ssh_key" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        "${admin_user}@${public_ip}" \
        "ls ~/.local/share/nvim/lazy/*/ 2>/dev/null | wc -l" 2>/dev/null || echo "0")

    if [ "$plugin_count" -lt 10 ]; then
        log_warning "LazyVim plugins may not be fully installed (found $plugin_count plugins)"
    else
        log_success "LazyVim verified with $plugin_count plugins"
    fi

    return 0
}

# Copy file to remote VM
copy_to_vm() {
    local ssh_key=$1
    local admin_user=$2
    local public_ip=$3
    local local_path=$4
    local remote_path=${5:-~/}

    if [ ! -f "$local_path" ]; then
        log_error "File not found: $local_path"
        return 1
    fi

    log_info "Copying $(basename "$local_path") to VM..."

    if scp -i "$ssh_key" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        "$local_path" "${admin_user}@${public_ip}:${remote_path}" 2>/dev/null; then
        log_success "File copied successfully"
        return 0
    else
        log_error "File copy failed"
        return 1
    fi
}

