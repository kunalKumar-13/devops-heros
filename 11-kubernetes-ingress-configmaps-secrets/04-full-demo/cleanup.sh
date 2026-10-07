#!/usr/bin/env bash
set -euo pipefail
kubectl delete -f ../03-ingress/path-based.yaml --ignore-not-found
kubectl delete -f apps.yaml --ignore-not-found
kubectl delete -f ../02-secret/db-secret.yaml --ignore-not-found
kubectl delete -f ../01-configmap/app-config.yaml --ignore-not-found
sudo sed -i '/kunal-devops.local/d' /etc/hosts
