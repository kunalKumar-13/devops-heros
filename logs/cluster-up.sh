#!/usr/bin/env bash
#
# Brings up a Kubernetes cluster for sections 08-11, on whatever this machine
# has. Installs kubectl and kind if they are missing, creates a two-node cluster
# with ports 80/443 mapped to localhost, and installs the NGINX ingress
# controller. Safe to re-run: an existing cluster is reused, not recreated.
#
#   ./logs/cluster-up.sh          # bring it up
#   ./logs/cluster-up.sh down     # tear it down
#
# Works on Linux and on macOS with Docker (including a Lima VM). If you already
# run minikube, you do not need this - capture-k8s.sh detects minikube too.
#
set -euo pipefail
cd "$(dirname "$0")/.."

ARCH="$(uname -m)"; case "$ARCH" in x86_64) ARCH=amd64 ;; aarch64|arm64) ARCH=arm64 ;; esac
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
CLUSTER=devops

say() { printf '\n==> %s\n' "$1"; }

if [ "${1:-up}" = down ]; then
  say "deleting the kind cluster"
  kind delete cluster --name "$CLUSTER"
  exit 0
fi

say "checking prerequisites"
if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not on PATH. kind needs a container runtime." >&2
  echo "On the Lima VM: limactl shell devops, then run this script there." >&2
  exit 1
fi
docker info >/dev/null 2>&1 || { echo "docker is installed but not running." >&2; exit 1; }
echo "docker: $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo unknown)"

if ! command -v kubectl >/dev/null 2>&1; then
  say "installing kubectl"
  V="$(curl -Ls https://dl.k8s.io/release/stable.txt)"
  curl -sSLo /tmp/kubectl "https://dl.k8s.io/release/$V/bin/$OS/$ARCH/kubectl"
  sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
fi
echo "kubectl: $(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*"' | head -1)"

if ! command -v kind >/dev/null 2>&1; then
  say "installing kind"
  curl -sSLo /tmp/kind "https://kind.sigs.k8s.io/dl/latest/kind-$OS-$ARCH"
  sudo install -m 0755 /tmp/kind /usr/local/bin/kind
fi
echo "kind: $(kind version)"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  say "cluster '$CLUSTER' already exists - reusing it"
else
  say "creating the cluster (control-plane + 1 worker, ports 80/443 mapped)"
  kind create cluster --config logs/kind-cluster.yaml --wait 120s
fi
kubectl cluster-info
kubectl get nodes -o wide

say "installing the NGINX ingress controller"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl -n ingress-nginx wait --for=condition=Available deploy/ingress-nginx-controller --timeout=300s || {
  echo "the ingress controller did not become ready; section 11 HTTP checks will fail" >&2; }

say "ready"
cat <<'MSG'
Next:
  ./logs/capture-k8s.sh          # run every section and write logs/k8s1..4.txt
  ./logs/capture-k8s.sh 3        # just one section

Section 11 curls http://kunal-devops.local - point it at localhost first:
  echo "127.0.0.1 kunal-devops.local api.kunal-devops.local shop.kunal-devops.local" | sudo tee -a /etc/hosts

Tear down with: ./logs/cluster-up.sh down
MSG
