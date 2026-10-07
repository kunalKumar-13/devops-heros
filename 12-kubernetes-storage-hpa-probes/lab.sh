#!/usr/bin/env bash
# Session 13 lab: storage, HPA and probes. Runs against the current kubectl
# context and prints a full transcript. Needs Metrics Server for the HPA.
set -uo pipefail
cd "$(dirname "$0")"
source ../labs/lib.sh
NS=production-webapp

banner "1. Storage classes available in this cluster"
run kubectl get storageclass

banner "2. emptyDir: two containers in one pod share a scratch volume"
run kubectl apply -f manifests/01-namespace.yaml
run kubectl apply -f manifests/06-emptydir-pod.yaml
runsh "kubectl wait --for=condition=Ready pod/emptydir-demo -n $NS --timeout=120s"
note "the reader container sees the file the writer container created"
runsh "kubectl exec -n $NS emptydir-demo -c reader -- cat /shared/msg"

banner "3. PersistentVolumeClaim, dynamically provisioned"
run kubectl apply -f manifests/02-pvc.yaml
run kubectl get pvc -n $NS

banner "4. Deployment (2 replicas, probes, PVC at /data) and Service"
run kubectl apply -f manifests/03-deployment.yaml
run kubectl apply -f manifests/04-service.yaml
runsh "kubectl rollout status deployment/web-app -n $NS --timeout=240s"
run kubectl get pods -n $NS -l app=web-app -o wide
run kubectl get pvc -n $NS
run kubectl get pv
note "the claim is now Bound to a PersistentVolume created for it"

banner "5. Probes, as Kubernetes sees them"
runsh "kubectl describe pod -n $NS -l app=web-app | grep -E '^Name:|Liveness|Readiness|Startup' | head -8"

banner "6. Task 1: data on the PVC survives the pod being deleted"
POD=$(kubectl get pods -n $NS -l app=web-app -o jsonpath='{.items[0].metadata.name}')
runsh "kubectl exec -n $NS $POD -- sh -c 'echo \"Student: Kunal Kumar (24BCS10027)\" > /data/student.txt'"
runsh "kubectl exec -n $NS $POD -- cat /data/student.txt"
run kubectl delete pod -n $NS "$POD"
runsh "kubectl rollout status deployment/web-app -n $NS --timeout=180s"
NEW=$(kubectl get pods -n $NS -l app=web-app --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
note "old pod: $POD   new pod: $NEW"
runsh "kubectl exec -n $NS $NEW -- cat /data/student.txt"

banner "7. Task 2: the Service answers"
runsh "kubectl run curl-svc -n $NS --rm -i --restart=Never --image=curlimages/curl:8.10.1 -- curl -s http://web-app.$NS.svc.cluster.local/"
run kubectl get endpoints web-app -n $NS

banner "8. Task 3: HPA scales out under load"
run kubectl apply -f manifests/05-hpa.yaml
note "waiting for Metrics Server to report CPU for the pods"
for i in $(seq 1 24); do
  kubectl get hpa web-app-hpa -n $NS -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null | grep -q . && break
  sleep 5
done
run kubectl get hpa -n $NS
note "starting 4 load generators that request the CPU-heavy page in a loop"
kubectl run load -n $NS --image=busybox:1.36 --restart=Never --command -- \
  sh -c 'for w in 1 2 3 4; do (while true; do wget -q -O- http://web-app >/dev/null; done) & done; wait' >/dev/null
for i in $(seq 1 18); do
  printf '%s@%s:~$ kubectl get hpa -n %s   # t+%ss\n' "$PROMPT_USER" "$PROMPT_HOST" "$NS" $((i * 10))
  kubectl get hpa -n $NS --no-headers
  sleep 10
done
echo
run kubectl get deployment web-app -n $NS
run kubectl get pods -n $NS -l app=web-app
runsh "kubectl describe hpa web-app-hpa -n $NS | sed -n '/Events:/,\$p'"
run kubectl delete pod load -n $NS --wait=false
