#!/usr/bin/env bash
# Map platform *.local hostnames to the EKS nginx ingress LoadBalancer IP.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -f "${ROOT}/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ROOT}/.env"
  set +a
fi

LB="$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"

if [[ -z "${LB}" ]]; then
  echo "ERROR: Could not get ingress LoadBalancer hostname. Is the cluster up?" >&2
  echo "  make kubectl ARGS='-n ingress-nginx get svc ingress-nginx-controller'" >&2
  exit 1
fi

IP="$(getent hosts "${LB}" | awk '{print $1}' | head -1)"
if [[ -z "${IP}" ]]; then
  echo "ERROR: Could not resolve ${LB}" >&2
  exit 1
fi

HOSTS=(
  credit.local
  mlflow.local
  llm.local
  langgraph.local
  trino.local
  minio.local
  airflow.local
)

MARKER="# data-platform EKS ingress (managed by terraform/scripts/setup-hosts.sh)"
LINE="${IP}  ${HOSTS[*]}"

echo "==> Load balancer: ${LB}"
echo "==> IP:            ${IP}"
echo "==> Hostnames:     ${HOSTS[*]}"
echo ""

update_hosts_file() {
  local file="$1"
  local tmp
  tmp="$(mktemp)"

  if [[ -f "${file}" ]]; then
    awk -v marker="${MARKER}" '
      $0 == marker { skip=1; next }
      skip && /^[0-9]/ { skip=0; next }
      !skip { print }
    ' "${file}" > "${tmp}"
  else
    : > "${tmp}"
  fi

  {
    cat "${tmp}"
    echo ""
    echo "${MARKER}"
    echo "${LINE}"
  } > "${file}.new"

  mv "${file}.new" "${file}"
  rm -f "${tmp}"
}

if [[ "${EUID}" -ne 0 ]]; then
  echo "Need sudo to edit /etc/hosts. Re-running with sudo..."
  exec sudo -E bash "$0" "$@"
fi

update_hosts_file /etc/hosts
echo "Updated /etc/hosts"

WIN_HOSTS="/mnt/c/Windows/System32/drivers/etc/hosts"
if [[ -f "${WIN_HOSTS}" ]]; then
  if update_hosts_file "${WIN_HOSTS}" 2>/dev/null; then
    echo "Updated Windows hosts: ${WIN_HOSTS}"
  else
    echo ""
    echo "Could not write Windows hosts (needs Administrator). Add manually in Notepad (Run as admin):"
    echo "  ${WIN_HOSTS}"
    echo "  ${LINE}"
  fi
fi

echo ""
echo "Open in browser:"
for h in "${HOSTS[@]}"; do
  echo "  http://${h}"
done
