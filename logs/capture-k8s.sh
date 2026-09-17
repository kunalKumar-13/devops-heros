#!/usr/bin/env bash
#
# Runs every Kubernetes exercise in sections 08-11 against a live minikube
# cluster and writes the transcript to logs/k8s1.txt .. logs/k8s4.txt, in the
# same banner style as the section 01-07 logs in this directory.
#
#   cd <repo root>
#   ./logs/capture-k8s.sh            # everything
#   ./logs/capture-k8s.sh 3          # just section 10 (services)
#
# Prerequisites on the VM: minikube + kubectl (see 08-kubernetes-fundamentals),
# and `minikube start --driver=docker` already run.
#
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
LOGS="logs"

banner() {
  printf '\n############################################################\n'
  printf '#  %s\n' "$1"
  printf '############################################################\n\n'
}

# run a command, echoing it with a prompt first, exactly as it appeared
run() {
  printf '%s@%s:~/devops-heros$ %s\n' "${USER:-kunal}" "$(hostname)" "$*"
  "$@" 2>&1
  printf '\n'
}

# same, but for a pipeline / shell one-liner passed as a single string
runsh() {
  printf '%s@%s:~/devops-heros$ %s\n' "${USER:-kunal}" "$(hostname)" "$1"
  bash -c "$1" 2>&1
  printf '\n'
}

# ---------------------------------------------------------------- section 08
section08() {
  banner "08.1  cluster is up, and the control plane runs as pods"
  run kubectl cluster-info
  run kubectl get nodes -o wide
  run kubectl version --short
  run kubectl get pods -n kube-system -o wide

  banner "08.2  every kind this cluster knows about"
  runsh "kubectl api-resources | head -40"
}

# ---------------------------------------------------------------- section 09
section09() {
  local M=09-kubernetes-workloads

  banner "09.1  Pod - schedule, inspect, delete (nothing brings it back)"
  run kubectl apply -f $M/manifests/01-pod.yaml
  runsh "kubectl wait --for=condition=Ready pod/nginx-pod --timeout=120s"
  run kubectl get pod nginx-pod -o wide
  runsh "kubectl describe pod nginx-pod | tail -20"
  run kubectl delete pod nginx-pod
  run kubectl get pods

  banner "09.2  ReplicaSet - self-healing"
  run kubectl apply -f $M/manifests/02-replicaset.yaml
  runsh "kubectl wait --for=jsonpath={.status.readyReplicas}=3 rs/nginx-rs --timeout=120s"
  run kubectl get rs nginx-rs
  run kubectl get pods -l app=nginx-rs -o wide
  runsh "VICTIM=\$(kubectl get pod -l app=nginx-rs -o jsonpath='{.items[0].metadata.name}'); echo deleting \$VICTIM; kubectl delete pod \$VICTIM"
  runsh "sleep 8; kubectl get pods -l app=nginx-rs"
  run kubectl scale rs nginx-rs --replicas=5
  runsh "sleep 8; kubectl get rs nginx-rs"
  run kubectl delete -f $M/manifests/02-replicaset.yaml

  banner "09.3  Deployment - rolling update, history, rollback"
  run kubectl apply -f $M/manifests/03-deployment.yaml
  run kubectl rollout status deploy/nginx-deploy --timeout=180s
  run kubectl get deploy,rs,pods -l app=nginx-deploy
  run kubectl set image deploy/nginx-deploy nginx=nginx:1.28-alpine
  run kubectl rollout status deploy/nginx-deploy --timeout=180s
  run kubectl get rs -l app=nginx-deploy
  run kubectl rollout history deploy/nginx-deploy
  run kubectl rollout undo deploy/nginx-deploy
  run kubectl rollout status deploy/nginx-deploy --timeout=180s
  runsh "kubectl get deploy nginx-deploy -o jsonpath='{.spec.template.spec.containers[0].image}'; echo"

  banner "09.4  DaemonSet - one pod per node"
  run kubectl apply -f $M/manifests/04-daemonset.yaml
  runsh "sleep 10; kubectl get ds node-logger"
  run kubectl get pods -l app=node-logger -o wide
  runsh "kubectl logs -l app=node-logger --tail=2"

  banner "09.5  StatefulSet - stable names, own volume, ordered creation"
  run kubectl apply -f $M/manifests/05-statefulset.yaml
  runsh "kubectl rollout status sts/web --timeout=240s"
  run kubectl get sts web
  run kubectl get pods -l app=web-sts -o wide
  run kubectl get pvc
  runsh "kubectl exec web-0 -- sh -c 'echo I am web-0 > /usr/share/nginx/html/index.html'"
  run kubectl delete pod web-0
  runsh "kubectl wait --for=condition=Ready pod/web-0 --timeout=180s; kubectl exec web-0 -- cat /usr/share/nginx/html/index.html"

  banner "09.6  pod lifecycle - Pending, Succeeded, Failed, CrashLoop, ImagePull"
  runsh "kubectl apply -f $M/pod-lifecycle/"
  runsh "sleep 45; kubectl get pods -l '!app' --no-headers | sort"
  runsh "kubectl describe pod lifecycle-pending | grep -A3 Events:"
  runsh "kubectl describe pod lifecycle-imagepull | grep -A5 Events:"
  runsh "kubectl get pod lifecycle-crashloop -o jsonpath='{.status.containerStatuses[0].restartCount}'; echo ' restarts'"
  runsh "kubectl logs lifecycle-crashloop --previous || true"
  runsh "kubectl logs lifecycle-init -c wait-for-service"
  runsh "kubectl exec lifecycle-sidecar -c server -- curl -s localhost || true"

  banner "09.7  troubleshooting - three deliberately broken manifests"
  runsh "kubectl apply -f $M/troubleshooting/"
  runsh "sleep 25; kubectl get svc broken-svc"
  runsh "kubectl get endpointslice -l kubernetes.io/service-name=broken-svc"
  runsh "kubectl describe svc broken-svc | grep -i selector"
  runsh "kubectl get pods --show-labels | grep -E 'broken|wrong|never'"
  runsh "kubectl get pods -l app=never-ready"
  runsh "kubectl describe pod -l app=never-ready | grep -i -A2 'readiness probe failed' | head -6"

  banner "09.8  deployment strategies"
  runsh "kubectl apply -f $M/rollout-strategies/02-blue-green.yaml"
  runsh "kubectl rollout status deploy/app-blue --timeout=180s; kubectl rollout status deploy/app-green --timeout=180s"
  runsh "kubectl describe svc app-svc | grep -i selector"
  runsh "kubectl patch svc app-svc -p '{\"spec\":{\"selector\":{\"app\":\"demo\",\"version\":\"green\"}}}'"
  runsh "kubectl describe svc app-svc | grep -i selector"
  runsh "kubectl get endpointslice -l kubernetes.io/service-name=app-svc -o wide"

  banner "09.9  cleanup"
  runsh "kubectl delete -f $M/rollout-strategies/02-blue-green.yaml --ignore-not-found"
  runsh "kubectl delete -f $M/troubleshooting/ --ignore-not-found"
  runsh "kubectl delete -f $M/pod-lifecycle/ --ignore-not-found"
  runsh "kubectl delete -f $M/manifests/ --ignore-not-found"
  runsh "kubectl delete pvc --all"
}

# ---------------------------------------------------------------- section 10
section10() {
  local M=10-kubernetes-services

  banner "10.0  the shared backend and a client pod"
  run kubectl apply -f $M/00-backend-deployment.yaml
  run kubectl apply -f $M/01-clusterip/client-pod.yaml
  run kubectl rollout status deploy/web --timeout=180s
  runsh "kubectl wait --for=condition=Ready pod/client --timeout=120s"
  run kubectl get pods -o wide

  banner "10.1  ClusterIP - internal only, and it load-balances"
  run kubectl apply -f $M/01-clusterip/service.yaml
  run kubectl get svc web-clusterip
  run kubectl get endpointslice -l kubernetes.io/service-name=web-clusterip -o wide
  runsh "for i in 1 2 3 4 5 6; do kubectl exec client -- curl -s http://web-clusterip/ | grep -i '^Hostname'; done"

  banner "10.2  ClusterIP with zero endpoints - the commonest failure"
  run kubectl scale deploy/web --replicas=0
  runsh "sleep 10; kubectl get endpointslice -l kubernetes.io/service-name=web-clusterip"
  runsh "kubectl exec client -- curl -s --max-time 5 http://web-clusterip/ || echo 'curl failed: no endpoints'"
  run kubectl scale deploy/web --replicas=3
  runsh "kubectl rollout status deploy/web --timeout=180s"

  banner "10.3  NodePort - reachable on the node IP"
  run kubectl apply -f $M/02-nodeport/service.yaml
  run kubectl get svc web-nodeport
  runsh "curl -s http://$(minikube ip):30080/ | head -12"
  runsh "minikube service web-nodeport --url"

  banner "10.4  LoadBalancer - EXTERNAL-IP pending without a cloud controller"
  run kubectl apply -f $M/03-loadbalancer/service.yaml
  runsh "sleep 10; kubectl get svc web-lb"
  runsh "echo 'EXTERNAL-IP stays <pending> on minikube - see the README; minikube tunnel fakes one'"

  banner "10.5  ExternalName - a DNS CNAME, no endpoints at all"
  run kubectl apply -f $M/04-externalname/service.yaml
  run kubectl get svc external-db
  runsh "kubectl exec client -- nslookup external-db.default.svc.cluster.local || true"

  banner "10.6  Headless - DNS returns every pod IP"
  run kubectl apply -f $M/05-headless/service.yaml
  run kubectl get svc web-headless
  runsh "kubectl exec client -- nslookup web-headless.default.svc.cluster.local || true"

  banner "10.7  Service DNS and the FQDN"
  runsh "kubectl exec client -- cat /etc/resolv.conf"
  runsh "kubectl exec client -- nslookup web-clusterip || true"
  runsh "kubectl -n kube-system get pods -l k8s-app=kube-dns"

  banner "10.8  cleanup"
  runsh "kubectl delete -f $M/05-headless/ -f $M/04-externalname/ -f $M/03-loadbalancer/ -f $M/02-nodeport/ -f $M/01-clusterip/ -f $M/00-backend-deployment.yaml --ignore-not-found"
}

# ---------------------------------------------------------------- section 11
section11() {
  local M=11-kubernetes-ingress-configmaps-secrets

  banner "11.1  the ingress controller (the Ingress object needs it to do anything)"
  run minikube addons enable ingress
  runsh "kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=240s"
  run kubectl -n ingress-nginx get pods,svc
  run kubectl get ingressclass

  banner "11.2  ConfigMap - env vars and a mounted file from one object"
  run kubectl apply -f $M/01-configmap/app-config.yaml
  runsh "kubectl get configmap app-config -o yaml | head -25"
  run kubectl apply -f $M/01-configmap/pod-env.yaml
  runsh "kubectl wait --for=condition=Ready pod/config-consumer --timeout=120s; kubectl logs config-consumer"

  banner "11.3  Secret - stringData in, base64 out, and it is only base64"
  run kubectl apply -f $M/02-secret/db-secret.yaml
  runsh "kubectl get secret db-secret -o jsonpath='{.data.DB_PASSWORD}'; echo"
  runsh "kubectl get secret db-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d; echo '   <-- decoded by anyone with get-secret RBAC'"
  run kubectl apply -f $M/02-secret/pod-secret.yaml
  runsh "kubectl wait --for=condition=Ready pod/secret-consumer --timeout=120s; kubectl logs secret-consumer"

  banner "11.4  path-based Ingress - one host, three backends"
  runsh "kubectl apply -f $M/04-full-demo/apps.yaml"
  runsh "kubectl rollout status deploy/api --timeout=180s; kubectl rollout status deploy/shop --timeout=180s; kubectl rollout status deploy/web --timeout=180s"
  runsh "kubectl apply -f $M/03-ingress/path-based.yaml"
  runsh "sleep 15; kubectl get ingress path-based"
  runsh "kubectl describe ingress path-based | sed -n '1,25p'"
  runsh "IP=\$(minikube ip); grep -q kunal-devops.local /etc/hosts || echo \"\$IP kunal-devops.local api.kunal-devops.local shop.kunal-devops.local\" | sudo tee -a /etc/hosts"
  runsh "curl -s http://kunal-devops.local/api/;  echo"
  runsh "curl -s http://kunal-devops.local/shop/; echo"
  runsh "curl -s http://kunal-devops.local/;      echo"

  banner "11.5  host-based Ingress - same cluster, routed on the Host header"
  runsh "kubectl apply -f $M/03-ingress/host-based.yaml"
  runsh "sleep 10; kubectl get ingress host-based"
  runsh "curl -s http://api.kunal-devops.local/;  echo"
  runsh "curl -s http://shop.kunal-devops.local/; echo"

  banner "11.6  config and secret values, read from inside the running pod"
  runsh "POD=\$(kubectl get pod -l app=api -o jsonpath='{.items[0].metadata.name}'); kubectl exec \$POD -- sh -c 'echo APP_ENV=\$APP_ENV; echo LOG_LEVEL=\$LOG_LEVEL; echo DB_PASSWORD=\$DB_PASSWORD'"

  banner "11.7  a 404 and a 503, on purpose - what each one means"
  runsh "curl -s -o /dev/null -w 'no matching rule -> HTTP %{http_code}\n' http://kunal-devops.local/nope/"
  runsh "kubectl scale deploy/shop --replicas=0; sleep 12; curl -s -o /dev/null -w 'rule matched, no endpoints -> HTTP %{http_code}\n' http://kunal-devops.local/shop/"
  runsh "kubectl scale deploy/shop --replicas=1; kubectl rollout status deploy/shop --timeout=180s"

  banner "11.8  cleanup"
  runsh "kubectl delete -f $M/03-ingress/ --ignore-not-found"
  runsh "kubectl delete -f $M/04-full-demo/apps.yaml --ignore-not-found"
  runsh "kubectl delete -f $M/02-secret/ -f $M/01-configmap/ --ignore-not-found"
  runsh "sudo sed -i '/kunal-devops.local/d' /etc/hosts"
}

WHICH="${1:-all}"
case "$WHICH" in
  all) section08 | tee "$LOGS/k8s1.txt"
       section09 | tee "$LOGS/k8s2.txt"
       section10 | tee "$LOGS/k8s3.txt"
       section11 | tee "$LOGS/k8s4.txt" ;;
  1)   section08 | tee "$LOGS/k8s1.txt" ;;
  2)   section09 | tee "$LOGS/k8s2.txt" ;;
  3)   section10 | tee "$LOGS/k8s3.txt" ;;
  4)   section11 | tee "$LOGS/k8s4.txt" ;;
  *)   echo "usage: $0 [all|1|2|3|4]" >&2; exit 2 ;;
esac

printf '\nWrote: %s\n' "$(ls -1 $LOGS/k8s*.txt 2>/dev/null | tr '\n' ' ')"
