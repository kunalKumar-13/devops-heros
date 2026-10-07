#!/usr/bin/env bash
# Session 14 lab: the troubleshooting challenge. Deploys a healthy app, breaks
# it in five different ways, diagnoses each one and fixes it.
set -uo pipefail
cd "$(dirname "$0")"
source ../labs/lib.sh

banner "1. Deploy the application"
run kubectl apply -f manifests/01-app.yaml
runsh "kubectl rollout status deployment/troubleshooting-app --timeout=180s"
run kubectl get pods -l app=troubleshooting-app -o wide

banner "2. Check the application answers through the Service"
runsh "kubectl run curl-ok --rm -i --restart=Never --image=curlimages/curl:8.10.1 -- curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://troubleshooting-service"

banner "3. Check the Service and its endpoints"
run kubectl get service troubleshooting-service
run kubectl get endpoints troubleshooting-service
note "endpoints list the pod IPs, so the Service has somewhere to send traffic"

banner "4. Broken pod: bad image"
run kubectl apply -f manifests/02-broken-image.yaml
sleep 25
run kubectl get pod broken-image
runsh "kubectl describe pod broken-image | sed -n '/Events:/,\$p'"
runsh "kubectl logs broken-image || true"
note "no logs: the container never started, so the evidence is only in the events"
run kubectl delete pod broken-image
note "fix: use a tag that exists"
runsh "kubectl run fixed-image --image=nginx:1.27-alpine && kubectl wait --for=condition=Ready pod/fixed-image --timeout=120s"
run kubectl get pod fixed-image
run kubectl delete pod fixed-image

banner "5. Service problem: selector does not match the pods"
run kubectl apply -f manifests/03-broken-service.yaml
run kubectl get service troubleshooting-service
run kubectl get endpoints troubleshooting-service
runsh "kubectl run curl-broken --rm -i --restart=Never --image=curlimages/curl:8.10.1 -- curl -s -m 5 -o /dev/null -w 'HTTP %{http_code}\n' http://troubleshooting-service || echo 'request failed: nothing behind the Service'"
note "root cause: compare the pod labels with the Service selector"
run kubectl get pods --show-labels -l app=troubleshooting-app
runsh "kubectl describe service troubleshooting-service | grep -E 'Selector|Endpoints'"
note "fix: put the selector back to app=troubleshooting-app"
run kubectl apply -f manifests/01-app.yaml
run kubectl get endpoints troubleshooting-service
runsh "kubectl run curl-fixed --rm -i --restart=Never --image=curlimages/curl:8.10.1 -- curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://troubleshooting-service"

banner "6. DNS: the Service name resolves inside the cluster"
runsh "kubectl run dns-test --rm -i --restart=Never --image=busybox:1.36 -- nslookup troubleshooting-service.default.svc.cluster.local"

banner "7. CrashLoopBackOff"
run kubectl apply -f manifests/04-crashloop.yaml
sleep 45
run kubectl get pod crashloop
runsh "kubectl logs crashloop --previous || kubectl logs crashloop"
runsh "kubectl describe pod crashloop | grep -E 'State|Reason|Exit Code|Restart Count|Back-off' | head -10"
run kubectl delete pod crashloop --wait=false

banner "8. Pending: the scheduler cannot place the pod"
run kubectl apply -f manifests/05-pending.yaml
sleep 10
run kubectl get pod pending
runsh "kubectl describe pod pending | sed -n '/Events:/,\$p'"
run kubectl delete pod pending --wait=false

banner "9. OOMKilled: the container exceeds its memory limit"
run kubectl apply -f manifests/06-oomkilled.yaml
sleep 25
run kubectl get pod oomkilled
runsh "kubectl get pod oomkilled -o jsonpath='reason={.status.containerStatuses[0].state.terminated.reason} exitCode={.status.containerStatuses[0].state.terminated.exitCode}'; echo"
run kubectl delete pod oomkilled --wait=false

banner "10. Events across the namespace, newest last"
runsh "kubectl get events --sort-by=.lastTimestamp | tail -25"

banner "11. kubectl exec into a healthy pod"
POD=$(kubectl get pods -l app=troubleshooting-app -o jsonpath='{.items[0].metadata.name}')
runsh "kubectl exec $POD -- sh -c 'hostname; nginx -v 2>&1; ls /usr/share/nginx/html'"
