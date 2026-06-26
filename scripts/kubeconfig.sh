#!/usr/bin/env bash
# Load .env via with-env.sh, then configure kubectl for the EKS cluster.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

REGION="${AWS_REGION:-$(terraform -chdir="${ROOT}" output -raw aws_region)}"
CLUSTER="${CLUSTER_NAME:-$(terraform -chdir="${ROOT}" output -raw cluster_name)}"

if [[ -z "${REGION}" || -z "${CLUSTER}" ]]; then
  echo "ERROR: Could not resolve region/cluster. Check AWS credentials (make verify-aws)." >&2
  exit 1
fi

echo "==> update-kubeconfig region=${REGION} cluster=${CLUSTER}"
aws eks update-kubeconfig --region "${REGION}" --name "${CLUSTER}"
echo ""
echo "kubectl needs AWS creds in the environment. Use either:"
echo "  bash scripts/with-env.sh kubectl get nodes"
echo "  make kubectl ARGS='get nodes'"
echo "Or run once: aws configure  (then plain kubectl works everywhere)"
