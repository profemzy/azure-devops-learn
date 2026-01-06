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
