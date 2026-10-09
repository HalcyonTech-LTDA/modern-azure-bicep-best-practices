#!/usr/bin/env bash
# ==============================================================================
# Azure Deployment Stack Lifecycle Orchestration Script
# Enforces pre-flight What-If verification and drift-preventing Deny Assignments
# ==============================================================================

set -euo pipefail

STACK_NAME="${1:-stack-workload-prod}"
RESOURCE_GROUP="${2:-rg-workload-prod}"
TEMPLATE_FILE="${3:-main.bicep}"
PARAMETERS_FILE="${4:-main.bicepparam}"

echo "=================================================================="
echo " Starting Deployment Stack Lifecycle Orchestration"
echo " Stack:          ${STACK_NAME}"
echo " Resource Group: ${RESOURCE_GROUP}"
echo " Template:       ${TEMPLATE_FILE}"
echo " Parameters:     ${PARAMETERS_FILE}"
echo "=================================================================="

# Ensure resource group exists
echo "==> Verifying Resource Group ${RESOURCE_GROUP}..."
az group create --name "${RESOURCE_GROUP}" --location eastus --tags ManagedBy=BicepStack -o none

# Step 1: Pre-flight What-If Analysis
echo "==> Executing pre-flight What-If analysis..."
az stack group create \
  --name "${STACK_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file "${TEMPLATE_FILE}" \
  --parameters "${PARAMETERS_FILE}" \
  --action-on-unmanage "deleteResources" \
  --deny-settings-mode "denyWriteAndDelete" \
  --what-if

# Step 2: Deploy Stack with Deny Assignments
echo "==> Applying Azure Deployment Stack..."
az stack group create \
  --name "${STACK_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file "${TEMPLATE_FILE}" \
  --parameters "${PARAMETERS_FILE}" \
  --action-on-unmanage "deleteResources" \
  --deny-settings-mode "denyWriteAndDelete" \
  --yes \
  --output json > stack_deployment_result.json

echo "==> Deployment Stack applied successfully!"

# Step 3: Verify Stack Resources & Deny Settings
echo "==> Verifying Stack state..."
az stack group show \
  --name "${STACK_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query "{name:name, provisioningState:provisioningState, denySettings:denySettings.mode, resourcesCount:length(resources)}" \
  --output table
