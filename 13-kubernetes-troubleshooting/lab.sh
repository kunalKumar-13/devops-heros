#!/usr/bin/env bash
# Session 14 lab: the troubleshooting challenge. Deploys a healthy app, breaks
# it in five different ways, diagnoses each one and fixes it.
set -uo pipefail
cd "$(dirname "$0")"
source ../labs/lib.sh

curl_svc()      { kubectl run "c$RANDOM" --rm -i --restart=Never --image=curlimages/curl:8.10.1 -- curl -sf -m 5 http://troubleshooting-service/ >/dev/null; }
endpoints_ip()  { kubectl get endpoints troubleshooting-service -o jsonpath='{.subsets[0].addresses[0].ip}'; }
has_endpoints() { [ -n "$(endpoints_ip)" ]; }
no_endpoints()  { [ -z "$(endpoints_ip)" ]; }
waiting_reason(){ kubectl get pod "$1" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}'; }
image_pull_err(){ waiting_reason project-broken-pod | grep -qE 'ErrImagePull|ImagePullBackOff'; }
crashlooping()  { [ "$(kubectl get pod crashloop -o jsonpath='{.status.containerStatuses[0].restartCount}')" -ge 1 ]; }
crash_logged()  { kubectl logs crashloop --previous 2>/dev/null | grep -q FATAL || kubectl logs crashloop | grep -q FATAL; }
unschedulable() { kubectl get pod pending -o jsonpath='{.status.conditions[?(@.type=="PodScheduled")].reason}' | grep -q Unschedulable; }
oom_killed()    { kubectl get pod oomkilled -o jsonpath='{.status.containerStatuses[0].state.terminated.reason}' | grep -q OOMKilled; }
# busybox nslookup exits 1 when the IPv6 (AAAA) lookup is empty, so judge by the answer, not the exit code
dns_resolves()  { [ "$(kubectl run "d$RANDOM" --rm -i --restart=Never --image=busybox:1.36 -- nslookup troubleshooting-service.default.svc.cluster.local 2>/dev/null | grep -A1 '^Name:' | grep -oE 'Address: [0-9.]+' | head -1 | cut -d' ' -f2)" = "$(kubectl get svc troubleshooting-service -o jsonpath='{.spec.clusterIP}')" ]; }

banner "1. Deploy the application"
run kubectl apply -f manifests/01-app.yaml
runsh "kubectl rollout status deployment/troubleshooting-app --timeout=180s"
run kubectl get pods -l app=troubleshooting-app -o wide

banner "2. Check the application: describe, logs, and from inside the pod"
POD=$(kubectl get pods -l app=troubleshooting-app -o jsonpath='{.items[0].metadata.name}')
runsh "kubectl describe pod $POD | grep -E '^(Name|Status|IP|Node):|Image:|Ready|Events' "
run kubectl logs "$POD" --tail=5
runsh "kubectl exec $POD -- curl -s localhost | grep -i '<title>'"
expect "inside the pod, nginx answers on localhost" bash -c "kubectl exec $POD -- curl -sf localhost | grep -qi nginx"
note "now the same request through the Service"
runsh "kubectl run curl-ok --rm -i --restart=Never --image=curlimages/curl:8.10.1 -- curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://troubleshooting-service"
expect "baseline: the Service answers" curl_svc

banner "3. Check the Service and its endpoints"
run kubectl get service troubleshooting-service
runsh "kubectl describe service troubleshooting-service | grep -E 'Selector|TargetPort|Endpoints'"
run kubectl get endpoints troubleshooting-service
note "endpoints list the pod IPs, so the Service has somewhere to send traffic"
expect "baseline: the Service has endpoints" has_endpoints

banner "4. Broken pod: bad image"
run kubectl apply -f manifests/02-broken-image.yaml
sleep 25
run kubectl get pod project-broken-pod
runsh "kubectl describe pod project-broken-pod | sed -n '/Events:/,\$p'"
runsh "kubectl logs project-broken-pod || true"
note "no logs: the container never started, so the evidence is only in the events"
expect "bad image: pod is stuck in ErrImagePull / ImagePullBackOff" image_pull_err
run kubectl delete pod project-broken-pod
note "fix: use a tag that exists"
runsh "kubectl run fixed-image --image=nginx:1.27-alpine && kubectl wait --for=condition=Ready pod/fixed-image --timeout=120s"
run kubectl get pod fixed-image
expect "bad image fixed: a pod with a real tag becomes Ready" kubectl wait --for=condition=Ready pod/fixed-image --timeout=10s
run kubectl delete pod fixed-image

banner "5. Service problem: selector does not match the pods"
run kubectl apply -f manifests/03-broken-service.yaml
sleep 3
run kubectl get service troubleshooting-service
run kubectl get endpoints troubleshooting-service
runsh "kubectl run curl-broken --rm -i --restart=Never --image=curlimages/curl:8.10.1 -- curl -s -m 5 -o /dev/null -w 'HTTP %{http_code}\n' http://troubleshooting-service || echo 'request failed: nothing behind the Service'"
expect "broken selector: the Service has no endpoints" no_endpoints
note "root cause: compare the pod labels with the Service selector"
run kubectl get pods --show-labels -l app=troubleshooting-app
runsh "kubectl describe service troubleshooting-service | grep -E 'Selector|Endpoints'"
note "fix: put the selector back to app=troubleshooting-app"
run kubectl apply -f manifests/01-app.yaml
sleep 3
run kubectl get endpoints troubleshooting-service
runsh "kubectl run curl-fixed --rm -i --restart=Never --image=curlimages/curl:8.10.1 -- curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://troubleshooting-service"
expect "selector fixed: endpoints are back" has_endpoints
expect "selector fixed: the Service answers again" curl_svc

banner "6. DNS: the Service name resolves inside the cluster"
runsh "kubectl run dns-test --rm -i --restart=Never --image=busybox:1.36 -- nslookup troubleshooting-service.default.svc.cluster.local"
expect "the Service DNS name resolves to the Service ClusterIP" dns_resolves

banner "7. CrashLoopBackOff"
run kubectl apply -f manifests/04-crashloop.yaml
sleep 45
run kubectl get pod crashloop
runsh "kubectl logs crashloop --previous || kubectl logs crashloop"
runsh "kubectl describe pod crashloop | grep -E 'State|Reason|Exit Code|Restart Count|Back-off' | head -10"
expect "crash loop: the container has been restarted" crashlooping
expect "crash loop: the logs show why (FATAL config error)" crash_logged
run kubectl delete pod crashloop --wait=false

banner "8. Pending: the scheduler cannot place the pod"
run kubectl apply -f manifests/05-pending.yaml
sleep 10
run kubectl get pod pending
runsh "kubectl describe pod pending | sed -n '/Events:/,\$p'"
expect "pending: PodScheduled is false with reason Unschedulable" unschedulable
run kubectl delete pod pending --wait=false

banner "9. OOMKilled: the container exceeds its memory limit"
run kubectl apply -f manifests/06-oomkilled.yaml
sleep 25
run kubectl get pod oomkilled
runsh "kubectl get pod oomkilled -o jsonpath='reason={.status.containerStatuses[0].state.terminated.reason} exitCode={.status.containerStatuses[0].state.terminated.exitCode}'; echo"
expect "out of memory: terminated with reason OOMKilled" oom_killed
run kubectl delete pod oomkilled --wait=false

banner "10. Events across the namespace, newest last"
runsh "kubectl get events --sort-by=.lastTimestamp | tail -25"

banner "11. kubectl exec into a healthy pod"
POD=$(kubectl get pods -l app=troubleshooting-app -o jsonpath='{.items[0].metadata.name}')
runsh "kubectl exec $POD -- sh -c 'hostname; nginx -v 2>&1; ls /usr/share/nginx/html'"
expect "exec works inside a healthy pod" kubectl exec "$POD" -- true

finish
