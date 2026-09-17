#!/usr/bin/env bash
# End-to-end demo: ConfigMap + Secret + Ingress on minikube.
# Run from this directory on the Ubuntu VM (kunal@kunal-devops).
set -euo pipefail

echo "==> 1. enable the NGINX ingress controller"
minikube addons enable ingress
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=180s

echo "==> 2. config and secret"
kubectl apply -f ../01-configmap/app-config.yaml
kubectl apply -f ../02-secret/db-secret.yaml

echo "==> 3. the three backends"
kubectl apply -f apps.yaml
kubectl rollout status deploy/api
kubectl rollout status deploy/shop
kubectl rollout status deploy/web

echo "==> 4. path-based ingress"
kubectl apply -f ../03-ingress/path-based.yaml
kubectl get ingress path-based

echo "==> 5. add the host to /etc/hosts (needs sudo)"
IP="$(minikube ip)"
grep -q 'kunal-devops.local' /etc/hosts \
  || echo "$IP kunal-devops.local api.kunal-devops.local shop.kunal-devops.local" | sudo tee -a /etc/hosts

echo "==> 6. prove the routing"
curl -s http://kunal-devops.local/api/  ; echo
curl -s http://kunal-devops.local/shop/ ; echo
curl -s http://kunal-devops.local/      ; echo

echo "==> 7. prove the config and secret landed in the pod"
POD="$(kubectl get pod -l app=api -o jsonpath='{.items[0].metadata.name}')"
kubectl exec "$POD" -- sh -c 'echo APP_ENV=$APP_ENV; echo LOG_LEVEL=$LOG_LEVEL; echo DB_PASSWORD=$DB_PASSWORD'

echo "==> 8. the secret is only base64, not encrypted"
kubectl get secret db-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d ; echo
