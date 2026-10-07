# Session 13 — Kubernetes Storage, HPA & Probes

**Kunal Kumar · Roll No. 24BCS10027**

The mini-project from the session: a production-style web app with persistent
storage, all three health probes, and a Horizontal Pod Autoscaler, then the
three verification tasks (storage survives a pod being deleted, the Service
answers, the HPA scales out under load).

Everything here was run on a real Kubernetes cluster (kind, inside GitHub
Actions) by [`lab.sh`](lab.sh). The full, unedited transcript is in
[`session-output.txt`](session-output.txt).

---

## Files

| File | What it is |
|---|---|
| [`manifests/01-namespace.yaml`](manifests/01-namespace.yaml) | `production-webapp` namespace |
| [`manifests/02-pvc.yaml`](manifests/02-pvc.yaml) | 500Mi `ReadWriteOnce` claim, `web-data` |
| [`manifests/03-deployment.yaml`](manifests/03-deployment.yaml) | 2 replicas, startup/readiness/liveness probes, CPU requests, PVC at `/data` |
| [`manifests/04-service.yaml`](manifests/04-service.yaml) | ClusterIP Service on port 80 |
| [`manifests/05-hpa.yaml`](manifests/05-hpa.yaml) | autoscaler, min 2, max 5, target 50% CPU |
| [`manifests/06-emptydir-pod.yaml`](manifests/06-emptydir-pod.yaml) | two containers sharing an `emptyDir` |
| [`lab.sh`](lab.sh) | runs everything below and prints each command with its output |

---

## Storage: three kinds of volume

| | Lives as long as | Use it for |
|---|---|---|
| **emptyDir** | the pod | scratch space, sharing files between containers in one pod |
| **hostPath** | the node | node agents that need the node's own files; avoid for apps, since the data is tied to one machine |
| **PersistentVolume + Claim** | until deleted, independent of any pod | anything that must survive restarts: databases, uploads |

A **PersistentVolumeClaim** is a request ("500Mi, read-write by one node"); a
**PersistentVolume** is the actual storage that satisfies it; a
**StorageClass** is the recipe for creating PVs on demand. Because the cluster
has a default StorageClass, creating the claim was enough: a volume was
provisioned and bound to it automatically (dynamic provisioning). Without one,
an admin would have to create a matching PV by hand and the claim would sit in
`Pending` until they did.

`ReadWriteOnce` means one **node** can mount the volume read-write, not one
pod, which is why both replicas can share it here. On a multi-node cluster the
scheduler keeps them on the node the volume lives on.

## Probes

| Probe | Question it answers | On failure |
|---|---|---|
| **startup** | has the app finished starting? | the other two probes wait; after the threshold the container is restarted |
| **readiness** | can it take traffic right now? | removed from the Service's endpoints, **not** restarted |
| **liveness** | is it stuck? | container is **restarted** |

The difference between readiness and liveness is the one that matters in
practice: a liveness probe that checks a dependency (a database, say) will
restart every healthy pod during that dependency's outage. Readiness is the
right place for "can I serve", liveness only for "am I wedged".

## HPA

The HPA compares the pods' CPU use with their CPU **request** and scales the
Deployment to bring the average back to the target (50% here). Two things are
required, and both explain the most common failure, `TARGETS: <unknown>/50%`:

1. the containers must declare `resources.requests.cpu`, since utilisation is a
   percentage *of the request*;
2. a metrics source must be installed (Metrics Server).

The image is `registry.k8s.io/hpa-example`, which does real CPU work on each
request, so a few load generators are enough to push it past 50%.

---

## What happened when it ran

Every command below ran in GitHub Actions on a fresh machine; these are verbatim excerpts of the transcript.

Run: <https://github.com/kunalKumar-13/devops-heros/actions/runs/37657639033>

**Verified results: 10 passed, 0 failed** (the checks the lab script makes; the job fails if any of them fail):

```text
  PASS  emptyDir: the reader container sees the writer's file
  PASS  PVC web-data is Bound to a dynamically provisioned volume
  PASS  web-app has 2 ready replicas
  PASS  startup, readiness and liveness probes are all configured
  PASS  a new pod replaced the deleted one
  PASS  the data written before the pod was deleted is still there
  PASS  the Service has endpoints
  PASS  the Service answers HTTP requests
  PASS  the HPA reads CPU metrics (not <unknown>)
  PASS  the HPA scaled web-app above its minimum of 2 (peak: 5 replicas)
```

**3. PersistentVolumeClaim, dynamically provisioned**

```console
kunal@kind-lab:~$ kubectl apply -f manifests/02-pvc.yaml
persistentvolumeclaim/web-data created

kunal@kind-lab:~$ kubectl get pvc -n production-webapp
NAME       STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
web-data   Pending                                      standard       <unset>                 0s

>>> WaitForFirstConsumer: the claim stays Pending until a pod uses it, so the volume is created on the node that pod lands on
```

**6. Task 1: data on the PVC survives the pod being deleted**

```console
kunal@kind-lab:~$ kubectl exec -n production-webapp web-app-66d887d887-ftfss -- sh -c 'echo "Student: Kunal Kumar (24BCS10027)" > /data/student.txt'

kunal@kind-lab:~$ kubectl exec -n production-webapp web-app-66d887d887-ftfss -- cat /data/student.txt
Student: Kunal Kumar (24BCS10027)

kunal@kind-lab:~$ kubectl delete pod -n production-webapp web-app-66d887d887-ftfss
pod "web-app-66d887d887-ftfss" deleted from production-webapp namespace

kunal@kind-lab:~$ kubectl rollout status deployment/web-app -n production-webapp --timeout=180s
Waiting for deployment "web-app" rollout to finish: 1 of 2 updated replicas are available...
deployment "web-app" successfully rolled out

>>> old pod: web-app-66d887d887-ftfss   new pod: web-app-66d887d887-qgv2k

kunal@kind-lab:~$ kubectl exec -n production-webapp web-app-66d887d887-qgv2k -- cat /data/student.txt
Student: Kunal Kumar (24BCS10027)
```

**7. Task 2: the Service answers**

```console
kunal@kind-lab:~$ kubectl run curl-svc -n production-webapp --rm -i -q --restart=Never --image=curlimages/curl:8.10.1 -- curl -s http://web-app.production-webapp.svc.cluster.local/
OK!
kunal@kind-lab:~$ kubectl get endpoints web-app -n production-webapp
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
NAME      ENDPOINTS                       AGE
web-app   10.244.1.65:80,10.244.1.67:80   23s
```

**8. Task 3: HPA scales out under load**

```console
kunal@kind-lab:~$ kubectl apply -f manifests/05-hpa.yaml
horizontalpodautoscaler.autoscaling/web-app-hpa created

>>> waiting for Metrics Server to report CPU for the pods

kunal@kind-lab:~$ kubectl get hpa -n production-webapp
NAME          REFERENCE            TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
web-app-hpa   Deployment/web-app   cpu: 1%/50%   2         5         2          30s

>>> starting 4 load generators that request the CPU-heavy page in a loop

kunal@kind-lab:~$ kubectl get hpa -n production-webapp   # t+10s
web-app-hpa   Deployment/web-app   cpu: 1%/50%   2     5     2     30s
kunal@kind-lab:~$ kubectl get hpa -n production-webapp   # t+20s
web-app-hpa   Deployment/web-app   cpu: 1%/50%   2     5     2     40s
kunal@kind-lab:~$ kubectl get hpa -n production-webapp   # t+30s
web-app-hpa   Deployment/web-app   cpu: 12%/50%   2     5     2     50s
kunal@kind-lab:~$ kubectl get hpa -n production-webapp   # t+40s
web-app-hpa   Deployment/web-app   cpu: 195%/50%   2     5     2     61s
kunal@kind-lab:~$ kubectl get hpa -n production-webapp   # t+50s
web-app-hpa   Deployment/web-app   cpu: 195%/50%   2     5     2     71s
kunal@kind-lab:~$ kubectl get hpa -n production-webapp   # t+60s
web-app-hpa   Deployment/web-app   cpu: 228%/50%   2     5     4     81s
kunal@kind-lab:~$ kubectl get hpa -n production-webapp   # t+70s
web-app-hpa   Deployment/web-app   cpu: 236%/50%   2     5     5     91s
kunal@kind-lab:~$ kubectl get hpa -n production-webapp   # t+80s
web-app-hpa   Deployment/web-app   cpu: 236%/50%   2     5     5     101s
kunal@kind-lab:~$ kubectl get hpa -n production-webapp   # t+90s
web-app-hpa   Deployment/web-app   cpu: 190%/50%   2     5     5     111s
kunal@kind-lab:~$ kubectl get hpa -n production-webapp   # t+100s
web-app-hpa   Deployment/web-app   cpu: 171%/50%   2     5     5     2m1s
kunal@kind-lab:~$ kubectl get hpa -n production-webapp   # t+110s
web-app-hpa   Deployment/web-app   cpu: 171%/50%   2     5     5     2m11s
kunal@kind-lab:~$ kubectl get hpa -n production-webapp   # t+120s
web-app-hpa   Deployment/web-app   cpu: 168%/50%   2     5     5     2m21s
kunal@kind-lab:~$ kubectl get hpa -n production-webapp   # t+130s
web-app-hpa   Deployment/web-app   cpu: 164%/50%   2     5     5     2m31s
kunal@kind-lab:~$ kubectl get hpa -n production-webapp   # t+140s
web-app-hpa   Deployment/web-app   cpu: 164%/50%   2     5     5     2m41s
kunal@kind-lab:~$ kubectl get hpa -n production-webapp   # t+150s
web-app-hpa   Deployment/web-app   cpu: 176%/50%   2     5     5     2m51s
kunal@kind-lab:~$ kubectl get hpa -n production-webapp   # t+160s
web-app-hpa   Deployment/web-app   cpu: 163%/50%   2     5     5     3m2s
kunal@kind-lab:~$ kubectl get hpa -n production-webapp   # t+170s
web-app-hpa   Deployment/web-app   cpu: 163%/50%   2     5     5     3m12s
[... 28 more lines in the full transcript ...]
```

