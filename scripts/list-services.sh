#!/usr/bin/env bash
# List platform services on EKS (pods, svc, ingress, ECR).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -f "${ROOT}/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ROOT}/.env"
  set +a
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "ERROR: kubectl cannot reach the cluster. Run: make kubeconfig" >&2
  exit 1
fi

LB="$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
INGRESS_TYPE="$(terraform -chdir="${ROOT}" output -raw ingress_type 2>/dev/null || echo unknown)"

echo "==> Cluster"
terraform -chdir="${ROOT}" output -raw cluster_name 2>/dev/null || kubectl config current-context
echo "    ingress: ${INGRESS_TYPE}"
[[ -n "${LB}" ]] && echo "    load balancer: ${LB}"
echo ""

echo "==> Ingress URLs (data-platform)"
if kubectl -n data-platform get ingress platform-ingress >/dev/null 2>&1; then
  while IFS= read -r host; do
    [[ -z "${host}" ]] && continue
    echo "    http://${host}"
  done < <(kubectl -n data-platform get ingress platform-ingress \
    -o jsonpath='{range .spec.rules[*]}{.host}{"\n"}{end}')
else
  echo "    (no platform-ingress found)"
fi
echo ""

echo "==> Kubernetes services (data-platform)"
kubectl -n data-platform get svc -o custom-columns=\
NAME:.metadata.name,\
TYPE:.spec.type,\
PORT:.spec.ports[*].port,\
CLUSTER-IP:.spec.clusterIP
echo ""

echo "==> Pods (data-platform)"
kubectl -n data-platform get pods -o custom-columns=\
NAME:.metadata.name,\
READY:.status.containerStatuses[*].ready,\
STATUS:.status.phase
echo ""

echo "==> Monitoring (port-forward to access)"
kubectl -n monitoring get svc -o custom-columns=\
NAME:.metadata.name,\
TYPE:.spec.type,\
PORT:.spec.ports[*].port 2>/dev/null || echo "    (monitoring namespace not found)"
echo "    Grafana:    make kubectl ARGS='-n monitoring port-forward svc/grafana 3000:3000'  → http://localhost:3000"
echo "    Prometheus: make kubectl ARGS='-n monitoring port-forward svc/prometheus 9090:9090'  → http://localhost:9090"
echo ""

echo "==> ECR repositories"
if terraform -chdir="${ROOT}" output -json ecr_repository_urls >/dev/null 2>&1; then
  terraform -chdir="${ROOT}" output -json ecr_repository_urls | python3 -c "
import json, sys
for name, url in json.load(sys.stdin).items():
    print(f'    {name}: {url}')
"
else
  echo "    (run from terraform/ after make apply)"
fi
