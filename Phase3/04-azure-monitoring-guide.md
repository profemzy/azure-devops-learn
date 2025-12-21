# Phase 3: Azure Monitoring & Observability Guide

This guide covers Azure Monitor, Log Analytics, metric alerts, and creating a comprehensive monitoring strategy for production environments.

---

## Table of Contents

1. [Monitoring Architecture](#monitoring-architecture)
2. [Lab 3.13: Log Analytics Workspace](#lab-313-log-analytics-workspace)
3. [Lab 3.14: Azure Monitor Metrics](#lab-314-azure-monitor-metrics)
4. [Lab 3.15: Alert Rules & Action Groups](#lab-315-alert-rules--action-groups)
5. [Lab 3.16: Service Health & Resource Health](#lab-316-service-health--resource-health)
6. [Professional Deliverables](#professional-deliverables)
7. [Interview Reinforcement](#interview-reinforcement)

---

## Monitoring Architecture

### Azure Monitor Pillars

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Monitor                             │
├─────────────────────┬───────────────────────────────────────┤
│   Metrics           │   Logs                                 │
│   (time-series)     │   (log events)                         │
├─────────────────────┼───────────────────────────────────────┤
│   - CPU %           │   - Application logs                   │
│   - Memory %        │   - Security logs                      │
│   - Disk I/O        │   - Audit logs                         │
│   - Network         │   - Diagnostic logs                    │
├─────────────────────┼───────────────────────────────────────┤
│   Alerts            │   Dashboards                           │
│   (notifications)   │   (visualization)                      │
└─────────────────────┴───────────────────────────────────────┘
```

### Recommended Workspace Architecture

```
Management Group: Corp
└── Subscription: Monitoring
    ├── Workspace: law-prod-eastus (Production)
    ├── Workspace: law-dev-eastus (Development)
    └── Workspace: law-security (Security logs only)
```

---

## Lab 3.13: Log Analytics Workspace

### Step 1: Create Log Analytics Workspace

```bash
# Variables
RESOURCE_GROUP="rg-devops-prod-monitoring-eastus"
LOCATION="eastus"
WORKSPACE_NAME="law-devops-prod-eastus"

# Create resource group (if not exists)
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --tags "Environment=Production" "Project=DevOps"

# Create Log Analytics workspace
az monitor log-analytics workspace create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WORKSPACE_NAME" \
  --location "$LOCATION" \
  --sku "PerGB2018" \
  --retention-days 30 \
  --tags "Environment=Production" "Project=DevOps"

# Get workspace details
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WORKSPACE_NAME" \
  --query "id" -o tsv)

WORKSPACE_CUSTOMER_ID=$(az monitor log-analytics workspace show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WORKSPACE_NAME" \
  --query "customerId" -o tsv)

echo "Workspace ID: $WORKSPACE_ID"
echo "Customer ID: $WORKSPACE_CUSTOMER_ID"
```

### Step 2: Configure Data Collection

```bash
# Enable VM insights for all VMs in resource group
az monitor vm-insights workspace configure \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WORKSPACE_NAME" \
  --vm-resource "/subscriptions/SUB-ID/resourceGroups/rg-devops-prod-compute-eastus"

# Enable Azure Monitor for Containers (AKS)
az monitor metrics diagnostic-settings create \
  --name "aks-diag" \
  --resource "/subscriptions/SUB-ID/resourceGroups/rg-devops-prod-compute-eastus/providers/Microsoft.ContainerService/managedClusters/aks-devops-prod" \
  --workspace "$WORKSPACE_ID" \
  --logs '[{"category": "kube-audit", "enabled": true}, {"category": "kube-audit-admin", "enabled": true}]' \
  --metrics '[{"category": "AllMetrics", "enabled": true}]'
```

### Step 3: Create Diagnostic Settings for Resources

```bash
# Create diagnostic setting for Virtual Machine
az monitor diagnostic-settings create \
  --name "vm-diag-devops-vm001" \
  --resource "/subscriptions/SUB-ID/resourceGroups/rg-devops-prod-compute-eastus/providers/Microsoft.Compute/virtualMachines/devops-vm-001" \
  --workspace "$WORKSPACE_ID" \
  --logs '[{"category": "BootDiagnostic", "enabled": true}, {"category": "ShutdownDiagnostic", "enabled": true}]' \
  --metrics '[{"category": "AllMetrics", "enabled": true}]'

# Create diagnostic setting for Key Vault
az monitor diagnostic-settings create \
  --name "kv-diag-devops-prod" \
  --resource "/subscriptions/SUB-ID/resourceGroups/rg-devops-prod-security-eastus/providers/Microsoft.KeyVault/vaults/kv-devops-prod-secrets" \
  --workspace "$WORKSPACE_ID" \
  --logs '[{"category": "AuditEvent", "enabled": true}]' \
  --metrics '[{"category": "AllMetrics", "enabled": true}]'

# Create diagnostic setting for Network Security Groups
az monitor diagnostic-settings create \
  --name "nsg-diag-devops-prod" \
  --resource "/subscriptions/SUB-ID/resourceGroups/rg-devops-prod-networking-eastus/providers/Microsoft.Network/networkSecurityGroups/nsg-devops-prod-app" \
  --workspace "$WORKSPACE_ID" \
  --logs '[{"category": "NetworkSecurityGroupEvent", "enabled": true}, {"category": "NetworkSecurityGroupRuleCounter", "enabled": true}]'

# List diagnostic settings for a resource
az monitor diagnostic-settings list \
  --resource "/subscriptions/SUB-ID/resourceGroups/rg-devops-prod-compute-eastus/providers/Microsoft.Compute/virtualMachines/devops-vm-001" \
  --output table
```

### Step 4: Query Log Analytics

```bash
# Run simple query
az monitor log-analytics query \
  --workspace "$WORKSPACE_CUSTOMER_ID" \
  --query "Heartbeat | take 10"

# Query VM performance
az monitor log-analytics query \
  --workspace "$WORKSPACE_CUSTOMER_ID" \
  --query "Perf | where ObjectName == 'Processor' and CounterName == '% Processor Time' | take 20"

# Query errors in last 24 hours
az monitor log-analytics query \
  --workspace "$WORKSPACE_CUSTOMER_ID" \
  --query "Syslog | where SeverityLevel == 'err' | where TimeGenerated > ago(24h) | take 50"

# Query Key Vault access
az monitor log-analytics query \
  --workspace "$WORKSPACE_CUSTOMER_ID" \
  --query "AzureDiagnostics | where resource_type == 'VAULTS' and operationName == 'VaultGet' | take 100"

# Export query results to CSV
az monitor log-analytics query \
  --workspace "$WORKSPACE_CUSTOMER_ID" \
  --query "Heartbeat | take 100" \
  --output csv-file > heartbeat-results.csv
```

### Step 5: Create Saved Queries

```bash
# Create a saved query (via REST API or Portal)
# Query: Failed VM login attempts
QUERY='
SecurityEvent
| where EventID == 4625
| summarize FailedCount = count() by bin(TimeGenerated, 1h), Account
| where FailedCount > 5
| order by FailedCount desc
'

# Save as function for reuse
# In Portal: Log Analytics → Saved Queries → Save as function
```

---

## Lab 3.14: Azure Monitor Metrics

### Step 1: Create Metric Alert

```bash
# Create action group (notification channel)
az monitor action-group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "ag-devops-prod-alerts" \
  --short-name "DevOpsAlerts" \
  --action "Email" "DevOpsTeam" "devops-team@example.com" \
  --action "Webhook" "Slack" "https://hooks.slack.com/services/xxx/xxx/xxx"

# Get action group ID
ACTION_GROUP_ID=$(az monitor action-group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "ag-devops-prod-alerts" \
  --query "id" -o tsv)

# Create metric alert for VM CPU usage
az monitor metrics alert create \
  --name "cpu-high-devops-vm001" \
  --resource-group "$RESOURCE_GROUP" \
  --condition "avg Percentage CPU > 80" \
  --description "CPU usage above 80%" \
  --window-size "5m" \
  --evaluation-frequency "1m" \
  --action "$ACTION_GROUP_ID" \
  --target "/subscriptions/SUB-ID/resourceGroups/rg-devops-prod-compute-eastus/providers/Microsoft.Compute/virtualMachines/devops-vm-001"

# Create alert for high memory usage
az monitor metrics alert create \
  --name "memory-high-devops-vm001" \
  --resource-group "$RESOURCE_GROUP" \
  --condition "avg Available Memory Bytes < 500000000" \
  --description "Available memory below 500MB" \
  --window-size "5m" \
  --evaluation-frequency "1m" \
  --action "$ACTION_GROUP_ID" \
  --target "/subscriptions/SUB-ID/resourceGroups/rg-devops-prod-compute-eastus/providers/Microsoft.Compute/virtualMachines/devops-vm-001"

# Create alert for disk usage
az monitor metrics alert create \
  --name "disk-high-devops-vm001" \
  --resource-group "$RESOURCE_GROUP" \
  --condition "avg Percentage Disk Used > 80" \
  --description "Disk usage above 80%" \
  --window-size "5m" \
  --evaluation-frequency "5m" \
  --action "$ACTION_GROUP_ID" \
  --target "/subscriptions/SUB-ID/resourceGroups/rg-devops-prod-compute-eastus/providers/Microsoft.Compute/virtualMachines/devops-vm-001"

# List all alerts
az monitor metrics alert list \
  --resource-group "$RESOURCE_GROUP" \
  --output table
```

### Step 2: Create Log Search Alert

```bash
# Create log search alert for errors
az monitor scheduled-query create \
  --name "log-errors-devops-prod" \
  --resource-group "$RESOURCE_GROUP" \
  --condition "count > 5" \
  --query "Syslog | where SeverityLevel == 'err' | count" \
  --query-type "ResultCount" \
  --description "More than 5 errors in last 5 minutes" \
  --action "$ACTION_GROUP_ID" \
  --evaluation-frequency "5m" \
  --window-size "5m" \
  --severity "2" \
  --workspace "$WORKSPACE_CUSTOMER_ID"

# Create alert for failed login attempts
az monitor scheduled-query create \
  --name "failed-logins-devops-prod" \
  --resource-group "$RESOURCE_GROUP" \
  --condition "count > 3" \
  --query "SecurityEvent | where EventID == 4625 | count" \
  --query-type "ResultCount" \
  --description "More than 3 failed login attempts" \
  --action "$ACTION_GROUP_ID" \
  --evaluation-frequency "5m" \
  --window-size "5m" \
  --severity "1" \
  --workspace "$WORKSPACE_CUSTOMER_ID"
```

### Step 3: Configure Action Groups

```bash
# Create action group with multiple notification types
az monitor action-group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "ag-devops-comprehensive" \
  --short-name "DevOps" \
  --action "Email" "DevOpsLead" "lead@example.com" \
  --action "Email" "DevOpsTeam" "team@example.com" \
  --action "SMS" "DevOpsLead" "+1234567890" \
  --action "Voice" "DevOpsLead" "+1234567890" \
  --action "Webhook" "PagerDuty" "https://events.pagerduty.com/v2/enqueue" \
  --action "Webhook" "Teams" "https://outlook.office.com/webhook/xxx"

# Enable ITSM integration
az monitor action-group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "ag-devops-itsm" \
  --short-name "ITSM" \
  --action "ITSMSession" "ServiceNow" "/subscriptions/SUB-ID/resourceGroups/rg-devops-prod-monitoring-eastus/providers/Microsoft.WorkloadMonitor/workloadInsights/xxx"

# List action groups
az monitor action-group list \
  --resource-group "$RESOURCE_GROUP" \
  --output table
```

---

## Lab 3.15: Azure Dashboards

### Step 1: Create Dashboard via CLI

```bash
# Create a simple dashboard
az portal dashboard create \
  --resource-group "$RESOURCE_GROUP" \
  --name "devops-overview-dashboard" \
  --location "$LOCATION" \
  --tags "Environment=Production" \
  --input '{"lenses":[{"name":"Overview","order":0,"parts":[{"name":"VM Metrics","model":{"type":"Extension/HubsExtension/PartType/MonitorBatchMetricsPart","displaySettings":{"title":"VM Metrics"}},"position":{"x":0,"y":0,"rowSpan":2,"colSpan":2}},{"name":"Log Analytics","model":{"type":"Extension/HubsExtension/PartType/LogAnalyticsAadTablePart"},"position":{"x":2,"y":0,"rowSpan":2,"colSpan":2}}]}],"metadata":{"model":{"id":"default"}}'
```

### Step 2: Create Dashboard with ARM Template

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "resources": [
    {
      "apiVersion": "2020-09-01-preview",
      "name": "devops-prod-dashboard",
      "type": "Microsoft.Portal/dashboards",
      "location": "eastus",
      "tags": {
        "Environment": "Production",
        "Project": "DevOps"
      },
      "properties": {
        "lenses": [
          {
            "order": 0,
            "parts": [
              {
                "position": {"x": 0, "y": 0, "colSpan": 6, "rowSpan": 4},
                "metadata": {
                  "type": "Extension/HubsExtension/PartType/MonitorChartPart",
                  "inputs": [
                    {
                      "name": "query",
                      "value": "Heartbeat | summarize dcount(Computer) by bin(TimeGenerated, 1h) | take 24"
                    },
                    {
                      "name": "timeRange",
                      "value": "Last 24 hours"
                    }
                  ]
                }
              },
              {
                "position": {"x": 6, "y": 0, "colSpan": 6, "rowSpan": 4},
                "metadata": {
                  "type": "Extension/HubsExtension/PartType/MonitorChartPart",
                  "inputs": [
                    {
                      "name": "query",
                      "value": "Perf | where CounterName == '% Processor Time' | summarize avg(CounterValue) by Computer, bin(TimeGenerated, 5m) | take 20"
                    },
                    {
                      "name": "timeRange",
                      "value": "Last 1 hour"
                    }
                  ]
                }
              }
            ]
          }
        ]
      }
    }
  ]
}
```

```bash
# Deploy dashboard
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "dashboards/devops-dashboard.json"
```

### Step 3: Create Workbooks

```json
{
  "contentVersion": "1.0.0.0",
  " workbook": {
    "name": "DevOps Overview Workbook",
    "displayName": "DevOps Overview",
    "kind": "shared",
    "properties": {
      "serializedContent": "{\"version\":\"Notebook/1.0\",\"items\":[{\"type\":1,\"content\":\"# DevOps Overview\",\"order\":0,\"width\":\"full\",\"viz\":null},{\"type\":3,\"content\":{\"title\":\"Active VMs\",\"query\":\"Heartbeat | summarize dcount(Computer)\",\"resourceType\":\"microsoft.operationalinsights/workspaces\"},\"order\":1,\"width\":\"small\"},{\"type\":3,\"content\":{\"title\":\"Errors (24h)\",\"query\":\"Syslog | where SeverityLevel == \\\"err\\\" | count\",\"resourceType\":\"microsoft.operationalinsights/workspaces\"},\"order\":2,\"width\":\"small\"},{\"type\":3,\"content\":{\"title\":\"Alerts Fired\",\"query\":\"Alert | where State == \\\"Fired\\\" | count\",\"resourceType\":\"microsoft.operationalinsights/workspaces\"},\"order\":3,\"width\":\"small\"}]}"
    }
  }
}
```

---

## Lab 3.16: Service Health & Resource Health

### Step 1: Configure Service Health Alerts

```bash
# Create Service Health alert
az monitor activity-log alert create \
  --name "service-health-devops-prod" \
  --resource-group "$RESOURCE_GROUP" \
  --condition "category=ServiceHealth" \
  --description "Alert on Azure service health issues" \
  --action "$ACTION_GROUP_ID" \
  --scope "/subscriptions/SUB-ID"

# Configure specific health conditions
az monitor activity-log alert create \
  --name "service-health-critical" \
  --resource-group "$RESOURCE_GROUP" \
  --condition "category=ServiceHealth, status=Active, level=Error" \
  --description "Alert on active service incidents" \
  --action "$ACTION_GROUP_ID" \
  --scope "/subscriptions/SUB-ID"

# List Service Health alerts
az monitor activity-log alert list \
  --resource-group "$RESOURCE_GROUP" \
  --output table
```

### Step 2: Create Resource Health Alerts

```bash
# Create Resource Health alert
az monitor activity-log alert create \
  --name "resource-health-devops-prod" \
  --resource-group "$RESOURCE_GROUP" \
  --condition "category=ResourceHealth, statusIn=Degraded,Unavailable" \
  --description "Alert when resources become unhealthy" \
  --action "$ACTION_GROUP_ID" \
  --scope "/subscriptions/SUB-ID/resourceGroups/rg-devops-prod-compute-eastus"

# Create alert for specific VM
az monitor activity-log alert create \
  --name "vm-health-devops-vm001" \
  --resource-group "$RESOURCE_GROUP" \
  --condition "category=ResourceHealth, resourceId=/subscriptions/SUB-ID/resourceGroups/rg-devops-prod-compute-eastus/providers/Microsoft.Compute/virtualMachines/devops-vm-001" \
  --description "Alert when devops-vm-001 health changes" \
  --action "$ACTION_GROUP_ID" \
  --scope "/subscriptions/SUB-ID"
```

### Step 3: Set Up Cost Management Alerts

```bash
# Create budget alert
az consumption budget create \
  --resource-group "$RESOURCE_GROUP" \
  --name "monthly-budget-devops-prod" \
  --amount 100 \
  --category "Cost" \
  --start-date "2025-01-01" \
  --end-date "2025-12-31" \
  --notifications '{
    "Actual_GreaterThan_80_Percent": {
      "enabled": true,
      "operator": "GreaterThan",
      "threshold": 80,
      "contactEmails": ["devops-team@example.com"]
    },
    "Actual_GreaterThan_100_Percent": {
      "enabled": true,
      "operator": "GreaterThan",
      "threshold": 100,
      "contactEmails": ["devops-team@example.com", "manager@example.com"]
    }
  }'
```

---

## Professional Deliverables

Complete Phase 3 Monitoring section by creating these artifacts:

| Deliverable | Description | Location |
|-------------|-------------|----------|
| Log Analytics Workspace | Configured with retention | Azure |
| Diagnostic Settings | Applied to all resources | Azure |
| Alert Rules | CPU, memory, disk, errors | Azure |
| Action Groups | Email, webhook notifications | Azure |
| Dashboards | Operations overview | Azure Portal |
| Runbook | Monitoring procedures | `docs/monitoring-runbook.md` |
| Alert Matrix | All alerts documented | `docs/alert-matrix.md` |

---

## Interview Reinforcement

### Q: How do you design a monitoring strategy?

> "I follow the USE method (Utilization, Saturation, Errors) for infrastructure and RED method (Rate, Errors, Duration) for services. I define SLIs (Service Level Indicators) for critical user journeys. I set SLOs (Service Level Objectives) based on business requirements. I create alerts that notify on-call teams only for actionable items. I use Log Analytics for debugging and metrics for capacity planning."

### Q: What's the difference between Log Analytics and Azure Monitor metrics?

> "Log Analytics stores structured log events with rich querying (KQL). It's for debugging, auditing, and complex analysis. Azure Monitor metrics store time-series numerical data at high frequency. They're for performance monitoring, dashboards, and alerts. They complement each other - logs tell you what happened, metrics tell you how it's performing."

### Q: How do you handle alert fatigue?

> "I implement proper alert severity levels (Critical, Warning, Info). I create alert aggregation rules to reduce noise. I use runbooks to automate common responses. I tune alert thresholds based on actual patterns. I regularly review and disable non-actionable alerts. I use escalation policies to ensure alerts are acknowledged."

### Q: What are the key metrics for a production VM?

> "CPU percentage (for utilization), Memory available (for capacity), Disk I/O and latency (for storage performance), Network in/out (for bandwidth), Disk used percentage (for capacity), and VM availability (for uptime). I also monitor specific application metrics like request latency and error rates."

### Q: How do you monitor for security incidents?

> "I enable Azure Defender for Cloud. I forward security logs to Log Analytics with Sentinel. I create alerts for failed logins, privilege escalations, and unusual API calls. I use Azure Monitor workbooks for security dashboards. I set up Microsoft Defender for Cloud threat protection."

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `az monitor log-analytics workspace create` | Create workspace |
| `az monitor diagnostic-settings create` | Configure diagnostics |
| `az monitor log-analytics query` | Run KQL query |
| `az monitor metrics alert create` | Create metric alert |
| `az monitor action-group create` | Create notification group |
| `az monitor activity-log alert create` | Create activity log alert |
| `az portal dashboard create` | Create dashboard |

---

## Phase 3 Complete Checklist

Before moving to Phase 4, ensure all deliverables are complete:

### Identity & Access
- [ ] Management group hierarchy created
- [ ] Resource groups with naming convention
- [ ] Custom roles configured
- [ ] Managed Identities implemented
- [ ] PIM for sensitive roles

### Network Security
- [ ] VNet with proper subnets
- [ ] NSGs with least-privilege rules
- [ ] Private Endpoints for critical resources
- [ ] Private DNS zones configured

### Key Vault
- [ ] Key Vault with RBAC
- [ ] Secrets stored and managed
- [ ] Diagnostic settings enabled
- [ ] Integration with applications

### Monitoring
- [ ] Log Analytics workspace
- [ ] Diagnostic settings on resources
- [ ] Alert rules configured
- [ ] Dashboards created
- [ ] Runbook documented

Ready to move to **Phase 4: Infrastructure as Code (Terraform)** →