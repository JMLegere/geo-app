#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Oracle Cloud Free-Tier ARM VM Setup
# =============================================================================
# Prerequisites:
#   1. OCI CLI installed and configured: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm
#   2. An SSH key pair (will use ~/.ssh/id_rsa.pub by default)
#   3. An OCI tenancy on the free tier
#
# Usage:
#   ./setup-vm.sh                    # interactive prompts
#   ./setup-vm.sh --compartment-id <ocid> --ssh-key-file ~/.ssh/id_ed25519.pub
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
VM_NAME="dev-server"
SHAPE="VM.Standard.A1.Flex"
OCPUS=4
MEMORY_GB=24
BOOT_VOLUME_GB=100  # Free tier allows up to 200GB total block storage
OS_IMAGE="Canonical Ubuntu 24.04"
SSH_KEY_FILE="$HOME/.ssh/id_rsa.pub"
COMPARTMENT_ID=""
AD=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --compartment-id) COMPARTMENT_ID="$2"; shift 2 ;;
    --ssh-key-file)   SSH_KEY_FILE="$2"; shift 2 ;;
    --name)           VM_NAME="$2"; shift 2 ;;
    --ocpus)          OCPUS="$2"; shift 2 ;;
    --memory)         MEMORY_GB="$2"; shift 2 ;;
    --ad)             AD="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--compartment-id OCID] [--ssh-key-file PATH] [--name NAME] [--ocpus N] [--memory N]"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Validate SSH key
if [[ ! -f "$SSH_KEY_FILE" ]]; then
  echo "ERROR: SSH public key not found at $SSH_KEY_FILE"
  echo "Generate one with: ssh-keygen -t ed25519"
  exit 1
fi
SSH_KEY=$(cat "$SSH_KEY_FILE")

# Get compartment ID (root compartment = tenancy OCID)
if [[ -z "$COMPARTMENT_ID" ]]; then
  COMPARTMENT_ID=$(oci iam compartment list --all --compartment-id-in-subtree true \
    --query 'data[0]."compartment-id"' --raw-output 2>/dev/null || true)
  if [[ -z "$COMPARTMENT_ID" ]]; then
    COMPARTMENT_ID=$(oci iam tenancy get --query 'data.id' --raw-output)
  fi
  echo "Using compartment: $COMPARTMENT_ID"
fi

# Get availability domain
if [[ -z "$AD" ]]; then
  AD=$(oci iam availability-domain list \
    --compartment-id "$COMPARTMENT_ID" \
    --query 'data[0].name' --raw-output)
  echo "Using availability domain: $AD"
fi

echo ""
echo "=== Setting up Oracle Cloud free-tier ARM VM ==="
echo "  Name:       $VM_NAME"
echo "  Shape:      $SHAPE ($OCPUS OCPUs, ${MEMORY_GB}GB RAM)"
echo "  Boot disk:  ${BOOT_VOLUME_GB}GB"
echo "  SSH key:    $SSH_KEY_FILE"
echo ""

# ---- Step 1: Create VCN ----
echo "[1/6] Creating VCN..."
VCN_ID=$(oci network vcn create \
  --compartment-id "$COMPARTMENT_ID" \
  --display-name "${VM_NAME}-vcn" \
  --cidr-blocks '["10.0.0.0/16"]' \
  --query 'data.id' --raw-output)
echo "  VCN: $VCN_ID"

# ---- Step 2: Create Internet Gateway ----
echo "[2/6] Creating Internet Gateway..."
IGW_ID=$(oci network internet-gateway create \
  --compartment-id "$COMPARTMENT_ID" \
  --vcn-id "$VCN_ID" \
  --display-name "${VM_NAME}-igw" \
  --is-enabled true \
  --query 'data.id' --raw-output)
echo "  IGW: $IGW_ID"

# Add route rule for internet access
RT_ID=$(oci network vcn get --vcn-id "$VCN_ID" \
  --query 'data."default-route-table-id"' --raw-output)
oci network route-table update \
  --rt-id "$RT_ID" \
  --route-rules "[{\"destination\":\"0.0.0.0/0\",\"destinationType\":\"CIDR_BLOCK\",\"networkEntityId\":\"$IGW_ID\"}]" \
  --force > /dev/null
echo "  Route table updated"

# ---- Step 3: Create Security List (SSH only) ----
echo "[3/6] Configuring security list..."
SL_ID=$(oci network vcn get --vcn-id "$VCN_ID" \
  --query 'data."default-security-list-id"' --raw-output)
oci network security-list update \
  --security-list-id "$SL_ID" \
  --ingress-security-rules '[
    {
      "source": "0.0.0.0/0",
      "protocol": "6",
      "tcpOptions": {"destinationPortRange": {"min": 22, "max": 22}}
    }
  ]' \
  --egress-security-rules '[
    {
      "destination": "0.0.0.0/0",
      "protocol": "all"
    }
  ]' \
  --force > /dev/null
echo "  Security list: SSH (22) ingress only"

# ---- Step 4: Create Subnet ----
echo "[4/6] Creating subnet..."
SUBNET_ID=$(oci network subnet create \
  --compartment-id "$COMPARTMENT_ID" \
  --vcn-id "$VCN_ID" \
  --display-name "${VM_NAME}-subnet" \
  --cidr-block "10.0.0.0/24" \
  --availability-domain "$AD" \
  --query 'data.id' --raw-output)
echo "  Subnet: $SUBNET_ID"

# ---- Step 5: Find Ubuntu ARM image ----
echo "[5/6] Finding Ubuntu ARM image..."
IMAGE_ID=$(oci compute image list \
  --compartment-id "$COMPARTMENT_ID" \
  --operating-system "Canonical Ubuntu" \
  --operating-system-version "24.04" \
  --shape "$SHAPE" \
  --sort-by TIMECREATED --sort-order DESC \
  --query 'data[0].id' --raw-output)
if [[ -z "$IMAGE_ID" || "$IMAGE_ID" == "null" ]]; then
  # Fallback to 22.04
  IMAGE_ID=$(oci compute image list \
    --compartment-id "$COMPARTMENT_ID" \
    --operating-system "Canonical Ubuntu" \
    --operating-system-version "22.04" \
    --shape "$SHAPE" \
    --sort-by TIMECREATED --sort-order DESC \
    --query 'data[0].id' --raw-output)
fi
echo "  Image: $IMAGE_ID"

# ---- Step 6: Launch Instance ----
echo "[6/6] Launching instance..."

# Read cloud-init file
CLOUD_INIT_FILE="$SCRIPT_DIR/cloud-init.yaml"
if [[ ! -f "$CLOUD_INIT_FILE" ]]; then
  echo "WARNING: cloud-init.yaml not found at $CLOUD_INIT_FILE, launching without user-data"
  CLOUD_INIT_ARG=""
else
  CLOUD_INIT_ARG="--user-data-file $CLOUD_INIT_FILE"
fi

INSTANCE_ID=$(oci compute instance launch \
  --compartment-id "$COMPARTMENT_ID" \
  --availability-domain "$AD" \
  --display-name "$VM_NAME" \
  --shape "$SHAPE" \
  --shape-config "{\"ocpus\": $OCPUS, \"memoryInGBs\": $MEMORY_GB}" \
  --subnet-id "$SUBNET_ID" \
  --image-id "$IMAGE_ID" \
  --assign-public-ip true \
  --boot-volume-size-in-gbs "$BOOT_VOLUME_GB" \
  --ssh-authorized-keys-file "$SSH_KEY_FILE" \
  $CLOUD_INIT_ARG \
  --query 'data.id' --raw-output)
echo "  Instance: $INSTANCE_ID"

# Wait for instance to be running
echo ""
echo "Waiting for instance to reach RUNNING state..."
oci compute instance get --instance-id "$INSTANCE_ID" \
  --wait-for-state RUNNING > /dev/null 2>&1 || true

# Get public IP
PUBLIC_IP=$(oci compute instance list-vnics \
  --instance-id "$INSTANCE_ID" \
  --query 'data[0]."public-ip"' --raw-output)

echo ""
echo "=== VM Ready ==="
echo "  Public IP:  $PUBLIC_IP"
echo "  SSH:        ssh ubuntu@$PUBLIC_IP"
echo ""
echo "  Instance:   $INSTANCE_ID"
echo "  VCN:        $VCN_ID"
echo "  Subnet:     $SUBNET_ID"
echo ""
echo "Cloud-init is still running in the background."
echo "Check progress with: ssh ubuntu@$PUBLIC_IP 'tail -f /var/log/cloud-init-output.log'"
