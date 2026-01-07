#!/bin/bash
# Phase 1: Intelligent Unified Cleanup Script
# Automatically detects and cleans up Phase 1 resources
# Usage (from Phase1 dir): ./scripts/common/cleanup-phase1.sh
#
# Environment Variables:
#   AZURE_DELETE_RG       - Delete resource groups? (default: true)
#   AZURE_DO_NOT_PROMPT   - Skip confirmations (default: false)
#   AZURE_RESOURCE_GROUP  - Specific RG to clean (default: auto-detect)
#   AZURE_DRY_RUN         - Show what would be deleted (default: false)

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "${SCRIPT_DIR}/az-common.sh"

# Configuration
DELETE_RG="${AZURE_DELETE_RG:-true}"
DRY_RUN="${AZURE_DRY_RUN:-false}"

# Phase 1 resource identifiers
PHASE1_TAGS=(
    "purpose=linux-lab"
    "environment=dev"
    "created-by=az-script"
)

PHASE1_RG_PATTERNS=(
    "devops-learn-rg"
    "rg-devops-learn"
    "rg-terraform-state"
)

PHASE1_VM_PATTERNS=(
    "devops-learn-vm"
    "bastion"
    "web[1-3]"
    "app[1-2]"
    "db1"
)

display_header "Phase 1: Intelligent Resource Cleanup"

# Check prerequisites
if ! check_prerequisites; then
    exit 1
fi

log_info "Scanning subscription for Phase 1 resources..."
echo ""

# Arrays to store discovered resources
declare -a FOUND_RGS=()
declare -a FOUND_VMS=()
declare -a RG_VM_MAP=()

# Function to check if RG contains Phase 1 resources
check_phase1_resources() {
    local rg=$1
    local has_phase1_resources=false

    # Check if RG name matches known patterns
    for pattern in "${PHASE1_RG_PATTERNS[@]}"; do
        if [[ "$rg" == *"$pattern"* ]] || [[ "$rg" == "$pattern" ]]; then
            has_phase1_resources=true
            break
        fi
    done

    # Check for VMs with Phase 1 patterns
    local vms
    vms=$(az vm list --resource-group "$rg" --query "[].name" -o tsv 2>/dev/null || echo "")

    if [ -n "$vms" ]; then
        while IFS= read -r vm; do
            for pattern in "${PHASE1_VM_PATTERNS[@]}"; do
                if [[ "$vm" =~ $pattern ]]; then
                    has_phase1_resources=true
                    FOUND_VMS+=("$rg:$vm")
                    break
                fi
            done
        done <<< "$vms"
    fi

    # Check for Phase 1 tags
    local tagged_resources
    tagged_resources=$(az resource list --resource-group "$rg" --tag "purpose=linux-lab" --query "[].name" -o tsv 2>/dev/null || echo "")

    if [ -n "$tagged_resources" ]; then
        has_phase1_resources=true
    fi

    if [ "$has_phase1_resources" = true ]; then
        FOUND_RGS+=("$rg")
    fi
}

# Scan all resource groups
log_info "Scanning resource groups..."
all_rgs=$(az group list --query "[].name" -o tsv 2>/dev/null || echo "")

if [ -z "$all_rgs" ]; then
    log_warning "No resource groups found in subscription"
    exit 0
fi

for rg in $all_rgs; do
    # Skip specific RG if provided
    if [ -n "${AZURE_RESOURCE_GROUP:-}" ] && [ "$rg" != "$AZURE_RESOURCE_GROUP" ]; then
        continue
    fi

    check_phase1_resources "$rg"
done

# Check if we found anything
if [ ${#FOUND_RGS[@]} -eq 0 ]; then
    log_warning "No Phase 1 resources found"
    echo ""
    echo "If you believe this is incorrect, you can:"
    echo "  1. Specify resource group manually: AZURE_RESOURCE_GROUP=my-rg $0"
    echo "  2. List all RGs: az group list -o table"
    exit 0
fi

# Display discovered resources
echo ""
display_header "Discovered Phase 1 Resources"

for rg in "${FOUND_RGS[@]}"; do
    echo ""
    log_info "Resource Group: $rg"

    # Count VMs
    vm_count=0
    vm_list=""
    for vm_entry in "${FOUND_VMS[@]}"; do
        vm_rg="${vm_entry%%:*}"
        vm_name="${vm_entry##*:}"

        if [ "$vm_rg" == "$rg" ]; then
            vm_count=$((vm_count + 1))
            vm_list="$vm_list  • $vm_name\n"
        fi
    done

    echo "  Virtual Machines: $vm_count"
    if [ -n "$vm_list" ]; then
        echo -e "$vm_list"
    fi

    # Show other resources count
    resource_count=$(az resource list --resource-group "$rg" --query "length(@)" -o tsv 2>/dev/null || echo "0")
    echo "  Total Resources: $resource_count"
done

echo ""
echo "Summary:"
echo "  Resource Groups: ${#FOUND_RGS[@]}"
echo "  VMs detected: ${#FOUND_VMS[@]}"

# Dry run mode
if [ "$DRY_RUN" = "true" ]; then
    echo ""
    log_warning "DRY RUN MODE - No resources will be deleted"
    echo ""
    echo "To actually delete, run:"
    echo "  AZURE_DRY_RUN=false $0"
    exit 0
fi

# Cleanup options
echo ""
if [ "${AZURE_DO_NOT_PROMPT:-}" != "true" ]; then
    echo "Cleanup options:"
    echo "  [1] Delete everything (all discovered resource groups)"
    echo "  [2] Delete VMs and resources (keep resource groups)"
    echo "  [3] Select specific resource groups to delete"
    echo "  [4] Cancel"
    echo ""
    read -p "Choose option [1-4]: " -n 1 -r
    echo ""

    case $REPLY in
        1)
            # Delete everything
            log_info "Will delete all discovered resource groups and their contents"
            SELECTED_RGS=("${FOUND_RGS[@]}")
            DELETE_RG="true"
            ;;
        2)
            # Delete VMs and resources, keep RGs
            log_info "Will delete VMs and their resources (keep resource groups for faster recreation)"
            SELECTED_RGS=("${FOUND_RGS[@]}")
            DELETE_RG="false"
            ;;
        3)
            # Select specific RGs
            echo ""
            echo "Select resource groups to delete (comma-separated numbers):"
            for i in "${!FOUND_RGS[@]}"; do
                echo "  [$((i+1))] ${FOUND_RGS[$i]}"
            done
            echo ""
            read -p "Enter selection: " selection

            SELECTED_RGS=()
            IFS=',' read -ra choices <<< "$selection"
            for choice in "${choices[@]}"; do
                idx=$((choice - 1))
                if [ $idx -ge 0 ] && [ $idx -lt ${#FOUND_RGS[@]} ]; then
                    SELECTED_RGS+=("${FOUND_RGS[$idx]}")
                fi
            done

            # Ask if they want to delete RGs or just VMs
            echo ""
            read -p "Delete resource groups? (y/N): " delete_rg_confirm
            if [[ "$delete_rg_confirm" =~ ^[Yy]$ ]]; then
                DELETE_RG="true"
            else
                DELETE_RG="false"
            fi
            ;;
        4)
            log_info "Cleanup cancelled by user"
            exit 0
            ;;
        *)
            log_error "Invalid selection"
            exit 1
            ;;
    esac
else
    # Non-interactive mode
    SELECTED_RGS=("${FOUND_RGS[@]}")
fi

# Confirm deletion
echo ""
if [ "$DELETE_RG" = "true" ]; then
    log_warning "This will delete the following resource groups and ALL their contents:"
    for rg in "${SELECTED_RGS[@]}"; do
        echo "  • $rg"
    done
else
    log_info "Will attempt to delete only VMs (keeping resource groups)"
fi

echo ""

if ! confirm_action "Proceed with cleanup?"; then
    log_info "Cleanup cancelled by user"
    exit 0
fi

# Perform cleanup
display_header "Cleaning Up Resources"

declare -a FAILED_RGS=()

for rg in "${SELECTED_RGS[@]}"; do
    echo ""

    if [ "$DELETE_RG" = "true" ]; then
        # Delete entire resource group
        log_info "Deleting resource group: $rg"

        if az group delete \
                --name "$rg" \
                --yes \
                --no-wait \
                2>/dev/null; then
            log_success "Initiated deletion: $rg"
        else
            log_error "Failed to delete: $rg"
            FAILED_RGS+=("$rg")
        fi
    else
        # Delete only VMs in the RG
        log_info "Deleting VMs in: $rg (keeping resource group)"

        for vm_entry in "${FOUND_VMS[@]}"; do
            vm_rg="${vm_entry%%:*}"
            vm_name="${vm_entry##*:}"

            if [ "$vm_rg" == "$rg" ]; then
                log_info "  Deleting VM: $vm_name"
                az vm delete \
                    --resource-group "$rg" \
                    --name "$vm_name" \
                    --yes \
                    --no-wait \
                    2>/dev/null || log_warning "  Failed to delete: $vm_name"
            fi
        done

        log_warning "  Resource group and other resources remain: $rg"
    fi
done

# Summary
echo ""
display_header "Cleanup Summary"

if [ ${#FAILED_RGS[@]} -eq 0 ]; then
    log_success "Cleanup initiated successfully"
    echo ""
    echo "Next steps:"
    echo "  1. Monitor deletion progress:"
    echo "     az group list --query \"[?contains(name, 'devops')].name\" -o table"
    echo ""
    echo "  2. Some resources may take several minutes to fully delete"
    echo ""
    echo "  3. Verify cleanup is complete:"
    echo "     az resource list --tag \"purpose=linux-lab\" -o table"
else
    log_warning "Some resources failed to delete"
    echo ""
    echo "Failed resource groups:"
    for rg in "${FAILED_RGS[@]}"; do
        echo "  • $rg"
    done
    echo ""
    echo "Possible reasons:"
    echo "  • Resources are still in use"
    echo "  • Insufficient permissions"
    echo "  • Network locks or retention policies"
    echo ""
    echo "To investigate:"
    echo "  az group show -n <resource-group>"

    exit 1
fi

echo ""
log_success "Phase 1 cleanup complete!"

