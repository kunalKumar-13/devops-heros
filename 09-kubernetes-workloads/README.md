# 09 — Pods, ReplicaSets, Deployments, DaemonSets & StatefulSets

Assignment: explain each core workload object, say where it is used, and deploy them.

All five manifests are in [`manifests/`](manifests/) and the four deployment strategies
in [`rollout-strategies/`](rollout-strategies/). Every file is commented with *why* each
field is there, not just what it is.

> **Evidence note** — the manifests and commands below are complete and ready to apply
> on the minikube setup from [section 08](../08-kubernetes-fundamentals/#5-lab-environment-used-for-sections-0911).
> Captured terminal output for the Kubernetes sections is not in this branch; sections
> 01–07 are the ones with screenshots.

---

## 1. Pod — [`manifests/01-pod.yaml`](manifests/01-pod.yaml)

The smallest thing Kubernetes schedules. Containers in a pod share a network namespace
(they reach each other on `localhost`), an IP, and any volumes you declare.

A bare pod is **not** managed. Delete it and nothing brings it back; the node it sits on
dies and it is simply gone. You write pods directly only for debugging, one-shot jobs
and sidecar experiments — everything long-lived goes behind a controller.

```bash
kubectl apply -f manifests/01-pod.yaml
kubectl get pod nginx-pod -o wide          # which node, which pod IP
kubectl describe pod nginx-pod             # events: Scheduled, Pulled, Created, Started
kubectl logs nginx-pod
kubectl exec -it nginx-pod -- sh
kubectl delete pod nginx-pod               # gone for good, nothing recreates it
```

**Pod phases you will meet:** `Pending` (unschedulable — no node fits, or the image is
still pulling), `Running`, `Succeeded`, `Failed`, and the two that are really container
states surfacing in `kubectl get pods`: `ImagePullBackOff` (wrong image name or private
registry) and `CrashLoopBackOff` (the process keeps exiting, so the kubelet keeps
restarting it with growing backoff).

---

## 2. ReplicaSet — [`manifests/02-replicaset.yaml`](manifests/02-replicaset.yaml)

**What it is.** A ReplicaSet's one job is to keep a stable set of replica pods running:
it counts pods matching its `selector` and creates or deletes until the count equals
`replicas`. That is the whole reconcile loop.

**Where it is used.** Almost never directly. The Kubernetes docs themselves recommend a
Deployment instead, because a ReplicaSet has **no rollout logic** — edit the image in
its pod template and existing pods are left untouched; only pods created *after* the
edit use the new image. A Deployment adds exactly that missing piece.

```bash
kubectl apply -f manifests/02-replicaset.yaml
kubectl get rs nginx-rs                    # DESIRED / CURRENT / READY
kubectl get pods -l app=nginx-rs -o wide

# prove self-healing: kill one pod and watch the ReplicaSet replace it
kubectl delete pod -l app=nginx-rs --field-selector status.phase=Running \
  --wait=false | head -1
kubectl get pods -l app=nginx-rs -w        # a new pod appears within seconds

kubectl scale rs nginx-rs --replicas=5
kubectl delete -f manifests/02-replicaset.yaml
```

Deleting a pod's **owner reference** is how this works: each pod carries
`ownerReferences: [nginx-rs]`, which is also why `kubectl delete rs` cascades to its
pods.

---

## 3. Deployment — [`manifests/03-deployment.yaml`](manifests/03-deployment.yaml)

**What it is.** Declarative updates for pods *and* ReplicaSets. You state the desired
state; the Deployment controller changes actual state at a controlled rate. The
ownership chain is **Deployment → ReplicaSet → Pods**: every change to the pod template
creates a *new* ReplicaSet and scales the old one down to zero, and keeping those old
ReplicaSets (up to `revisionHistoryLimit`) is precisely what makes rollback instant.

**Where it is used.** Every stateless workload — web servers, APIs, workers. It is the
default answer.

```bash
kubectl apply -f manifests/03-deployment.yaml
kubectl get deploy,rs,pods -l app=nginx-deploy    # see all three layers at once

# rolling update
kubectl set image deploy/nginx-deploy nginx=nginx:1.28-alpine
kubectl rollout status deploy/nginx-deploy
kubectl get rs -l app=nginx-deploy                # old RS at 0, new RS at 3

# history and rollback
kubectl rollout history deploy/nginx-deploy
kubectl rollout undo deploy/nginx-deploy
kubectl rollout undo deploy/nginx-deploy --to-revision=1

# pause mid-rollout (to batch several edits into one rollout)
kubectl rollout pause deploy/nginx-deploy
kubectl rollout resume deploy/nginx-deploy

kubectl scale deploy/nginx-deploy --replicas=6
```

`maxUnavailable: 0` + `maxSurge: 1` in the manifest is the conservative setting:
capacity never dips below the declared replica count, and one pod at a time is replaced.
Without a **readiness probe** a rolling update is dangerous — Kubernetes would consider
a pod "available" the moment the container starts and would happily tear down the old
one before the new one can serve.

---

## 4. DaemonSet — [`manifests/04-daemonset.yaml`](manifests/04-daemonset.yaml)

**What it is.** Ensures that all (or a labelled subset of) nodes run exactly **one** copy
of a pod. Add a node to the cluster and the pod appears on it automatically; remove the
node and the pod is garbage collected. There is no `replicas` field — the node count
*is* the replica count.

**Where it is used.** Cluster-wide infrastructure that must exist on every machine:

* **log collection** — Fluent Bit, Fluentd, Promtail, Filebeat
* **node monitoring** — Prometheus `node-exporter`, Datadog/New Relic agents
* **networking** — the CNI agent itself (Calico, Cilium) and `kube-proxy`
* **storage** — Ceph/GlusterFS node daemons, CSI node plugins
* **security** — Falco, vulnerability and compliance scanners

```bash
kubectl apply -f manifests/04-daemonset.yaml
kubectl get ds node-logger        # DESIRED = number of eligible nodes
kubectl get pods -l app=node-logger -o wide
kubectl logs -l app=node-logger --tail=3
```

Two details worth knowing, both in the manifest: the **toleration** for
`node-role.kubernetes.io/control-plane`, without which the DaemonSet skips the control
plane node and you get zero pods on single-node minikube; and the `spec.nodeName`
**fieldRef**, which is how a pod learns which node it landed on.

---

## 5. StatefulSet — [`manifests/05-statefulset.yaml`](manifests/05-statefulset.yaml)

**What it is.** Deployments treat pods as interchangeable and disposable — random name
suffixes, any order, shared or no storage. A StatefulSet instead gives each pod a
**sticky identity** it keeps across restarts and rescheduling:

* **stable names** — `web-0`, `web-1`, `web-2`, not `web-7d9f8b-x4k2p`
* **stable DNS** — `web-0.web-headless.default.svc.cluster.local`, via the headless
  Service in the same file
* **stable storage** — `volumeClaimTemplates` gives every pod its own PVC, and `web-1`
  reattaches to *its own* volume when it restarts
* **ordered operations** — created `0 → 1 → 2`, each waiting for the previous to be
  Ready; deleted and rolling-updated in reverse

**Where it is used.** Anything where the members are not interchangeable: distributed
databases (Cassandra, MongoDB, MySQL/Postgres clusters), message brokers (Kafka,
RabbitMQ), consensus stores (ZooKeeper, etcd, Consul), Redis clusters.

```bash
kubectl apply -f manifests/05-statefulset.yaml
kubectl get sts web
kubectl get pods -l app=web-sts -w         # watch web-0, then web-1, then web-2
kubectl get pvc                            # data-web-0, data-web-1, data-web-2

# stable identity, proved
kubectl exec web-0 -- sh -c 'echo "I am web-0" > /usr/share/nginx/html/index.html'
kubectl delete pod web-0                   # comes back with the SAME name and volume
kubectl exec web-0 -- cat /usr/share/nginx/html/index.html

# per-pod DNS (needs the headless service)
kubectl run dnsutil --image=busybox:1.36 --restart=Never -it --rm -- \
  nslookup web-0.web-headless.default.svc.cluster.local
```

A Deployment cannot do any of this: `volumeClaimTemplates` does not exist there, so all
replicas share one PVC (or none), and no pod has a predictable name to address.

---

## 6. Deployment strategies — [`rollout-strategies/`](rollout-strategies/)

| Strategy | Downtime | Both versions live? | Traffic split | File |
|---|---|---|---|---|
| **RollingUpdate** (default) | none | briefly, during the roll | gradual, by replica count | [`04-rolling-update.yaml`](rollout-strategies/04-rolling-update.yaml) |
| **Recreate** | yes | never | n/a | [`01-recreate.yaml`](rollout-strategies/01-recreate.yaml) |
| **Blue/green** | none | yes, but only one gets traffic | all-or-nothing switch | [`02-blue-green.yaml`](rollout-strategies/02-blue-green.yaml) |
| **Canary** | none | yes, both get traffic | by replica ratio | [`03-canary.yaml`](rollout-strategies/03-canary.yaml) |

**RollingUpdate** — replace pods a few at a time, gated by readiness probes. The default,
and correct for most services.

**Recreate** — kill everything, then start the new version. You accept downtime in
exchange for the guarantee that v1 and v2 never run simultaneously, which matters when
v2 ships a backwards-incompatible schema migration.

**Blue/green** — two complete Deployments, one Service. The Service's `selector` is the
switch:

```bash
kubectl apply -f rollout-strategies/02-blue-green.yaml
kubectl patch svc app-svc -p '{"spec":{"selector":{"app":"demo","version":"green"}}}'
# instant rollback:
kubectl patch svc app-svc -p '{"spec":{"selector":{"app":"demo","version":"blue"}}}'
```

Cutover and rollback are both atomic and instant; the cost is running double capacity.

**Canary** — one Service selecting a label both Deployments share, so it load-balances
across them. 9 stable + 1 canary sends roughly 10% of requests to the new version:

```bash
kubectl apply -f rollout-strategies/03-canary.yaml
kubectl scale deploy/app-canary --replicas=3    # widen to ~25%
kubectl scale deploy/app-stable --replicas=0    # promote
```

Replica-ratio canarying is the plain-Kubernetes version; for real percentage control
independent of pod count you use ingress-level weighting
(`nginx.ingress.kubernetes.io/canary-weight`) or a service mesh.

---

## 7. Cheat sheet

```bash
kubectl get all                                  # everything in the namespace
kubectl get pods -o wide --show-labels
kubectl describe <kind>/<name>                   # events live at the bottom - read them first
kubectl logs <pod> -c <container> --previous     # logs of the crashed instance
kubectl exec -it <pod> -- sh
kubectl apply -f <file>                          # declarative, idempotent
kubectl diff -f <file>                           # what apply would change
kubectl explain deployment.spec.strategy         # schema, from the cluster itself
kubectl rollout status|history|undo|pause|resume deploy/<name>
kubectl scale deploy/<name> --replicas=N
kubectl get events --sort-by=.lastTimestamp
kubectl api-resources                            # every kind this cluster knows
```
