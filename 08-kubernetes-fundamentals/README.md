# 08 — Kubernetes Fundamentals & Architecture

Assignment: read the [Kubernetes architecture docs](https://kubernetes.io/docs/concepts/architecture/)
and write up what a cluster is actually made of.

> **Evidence.** Run on a real cluster (kind, 2 nodes) in GitHub Actions by
> [`logs/capture-k8s.sh`](../logs/capture-k8s.sh) `1`, which prints each command before its
> output. The full, unedited transcript is [`logs/k8s1.txt`](../logs/k8s1.txt): the cluster coming up, its nodes, the control plane running as pods in kube-system, and every kind of object the API server knows about.
> Run: <https://github.com/kunalKumar-13/devops-heros/actions/runs/37657639033>

---

## 1. What a cluster is

Deploy Kubernetes and you get a **cluster**: a set of worker machines called **nodes**
that run containerised applications, plus a **control plane** that decides what should
run where. Every cluster has at least one worker node. Nodes host **Pods** — the
smallest deployable unit, one or more containers sharing a network namespace and
storage.

The whole system is a **declarative control loop**. You never tell Kubernetes *"start
this container on that machine."* You write down the state you want, and a set of
controllers keep comparing *desired state* against *actual state* and acting on the
difference. That single idea explains almost every behaviour in the rest of this
repository — why a deleted pod comes back, why a rolling update happens gradually, why
a DaemonSet appears on a brand-new node without anyone asking.

```
                        ┌─────────────────────── CONTROL PLANE ───────────────────────┐
   kubectl ──HTTPS──►   │  kube-apiserver ──► etcd (the only thing that stores state) │
                        │        ▲                                                    │
                        │        ├── kube-scheduler          (unassigned pod → node)  │
                        │        ├── kube-controller-manager  (reconcile loops)        │
                        │        └── cloud-controller-manager (cloud LBs, routes)     │
                        └────────────────────────────┬────────────────────────────────┘
                                                     │ watch / report
              ┌──────────────────────────────────────┼──────────────────────────────────┐
              │                                      │                                  │
     ┌────────▼─────────┐                   ┌────────▼─────────┐              ┌─────────▼────────┐
     │  NODE 1          │                   │  NODE 2          │              │  NODE 3          │
     │  kubelet         │                   │  kubelet         │              │  kubelet         │
     │  kube-proxy      │                   │  kube-proxy      │              │  kube-proxy      │
     │  containerd      │                   │  containerd      │              │  containerd      │
     │  └── Pods        │                   │  └── Pods        │              │  └── Pods        │
     └──────────────────┘                   └──────────────────┘              └──────────────────┘
```

---

## 2. Control plane components

### `kube-apiserver`
The front door. It exposes the Kubernetes REST API and is the **only** component that
talks to etcd — everything else, including `kubectl` and the kubelets, goes through it.
Its real job is authentication, authorisation (RBAC), admission control and validation;
once a request survives all of that, the resulting object is persisted. Stateless, so it
scales horizontally behind a load balancer.

### `etcd`
A consistent, highly-available key-value store, and the cluster's single source of
truth: every object you have ever created lives here. It uses the **Raft** consensus
algorithm, which is why production clusters run 3 or 5 members (an odd number, to keep a
quorum). **Back etcd up** — lose it and you have lost the cluster, even if every worker
node is still healthy.

### `kube-scheduler`
Watches for Pods with no `spec.nodeName` and picks a node for each one. Two phases:

1. **Filtering** — throw out nodes that *cannot* run the pod: not enough free CPU/memory
   for its `requests`, a `nodeSelector`/affinity rule that does not match, a taint the
   pod does not tolerate, a required port already taken, a volume that cannot attach.
2. **Scoring** — rank the survivors (spread across nodes, image already cached locally,
   affinity preferences) and bind the pod to the winner.

Note what it does *not* do: it never starts a container. It only writes the node name
back through the API server.

### `kube-controller-manager`
One binary running many independent reconcile loops. Each loop watches a resource type
and drives reality toward the spec:

| Controller | What it reconciles |
|---|---|
| **Node** | notices when a node stops heartbeating and evicts its pods |
| **ReplicaSet** | creates/deletes pods until the count matches `replicas` |
| **Deployment** | creates ReplicaSets and drives rollouts |
| **Job / CronJob** | runs pods to completion, on a schedule |
| **EndpointSlice** | keeps the list of ready pod IPs behind each Service current |
| **ServiceAccount** | creates the default ServiceAccount in every new namespace |
| **PersistentVolume** | binds PVCs to PVs, provisions storage |

### `cloud-controller-manager`
The cloud-specific half, split out so the core stays vendor-neutral. It is what turns a
`type: LoadBalancer` Service into a real cloud load balancer, labels nodes with their
region/zone, and removes Node objects for VMs that the provider has deleted. On minikube
it is simply absent — which is exactly why `EXTERNAL-IP` sits at `<pending>` in
section 10.

---

## 3. Node components

### `kubelet`
The agent on every node. It takes the PodSpecs assigned to its node and makes sure the
described containers are running and healthy: pulls images via the container runtime,
mounts volumes, runs the liveness/readiness/startup probes, restarts containers per
`restartPolicy`, and reports status back to the API server. It manages only containers
Kubernetes created — a container you start by hand with `docker run` is invisible to it.

### `kube-proxy`
Implements the **Service** abstraction on each node. It watches Services and
EndpointSlices and programs the kernel — `iptables` rules by default, IPVS at larger
scale — so that traffic to a Service's virtual IP is DNAT'd to one of the ready pod IPs.
There is no proxy process in the data path in iptables mode; the kernel does the work.
This is the machinery behind every service type in section 10. (Clusters using an eBPF
CNI such as Cilium can replace kube-proxy entirely.)

### Container runtime
The software that actually runs containers, spoken to through the **CRI** (Container
Runtime Interface): **containerd**, **CRI-O**, or any other CRI implementation. Docker
Engine is no longer called directly — the `dockershim` was removed in Kubernetes 1.24 —
though images built with Docker still run fine, because they are OCI images.

### Addons (per cluster, not per node)
**CoreDNS** gives every Service a DNS name, a **CNI plugin** (Calico, Flannel, Cilium)
gives every pod a routable IP, and an **ingress controller** handles the L7 routing in
section 11.

---

## 4. What actually happens on `kubectl apply -f deployment.yaml`

1. `kubectl` turns the YAML into a REST call to **kube-apiserver**.
2. The API server authenticates the caller, checks RBAC, runs admission webhooks,
   validates the object, and writes it to **etcd**.
3. The **Deployment controller** sees a Deployment with no ReplicaSet and creates one.
4. The **ReplicaSet controller** sees 0 of 3 pods and creates three Pod objects — each
   with no node assigned.
5. The **scheduler** filters and scores nodes, then binds each pod to one.
6. The **kubelet** on each chosen node pulls the image through the **CRI**, asks the CNI
   plugin for an IP, mounts volumes, starts the container and begins probing it.
7. Once the readiness probe passes, the **EndpointSlice controller** adds the pod IP to
   the Service's endpoints and **kube-proxy** programs the kernel rules — only now does
   the pod receive traffic.

Nobody in that chain gave an order to anyone else. Each component watched the API server
and acted on a difference it cared about.

---

## 5. Lab environment used for sections 09–11

The whole setup is scripted in [`logs/cluster-up.sh`](../logs/cluster-up.sh) (kind, two
nodes, ingress controller installed, ports 80/443 mapped to localhost) if you would
rather not do it by hand. The manual minikube path:

```bash
# on the Ubuntu 26.04 VM (kunal@kunal-devops), Docker already installed
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-arm64
sudo install minikube-linux-arm64 /usr/local/bin/minikube

curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

minikube start --driver=docker --cpus=2 --memory=3900
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -n kube-system        # the control plane, running as pods
```

`kubectl get pods -n kube-system` is the useful one to look at after reading the above:
on minikube every component in section 2 is itself a pod — `etcd-minikube`,
`kube-apiserver-minikube`, `kube-scheduler-minikube`,
`kube-controller-manager-minikube`, `kube-proxy-*` and `coredns-*` — so the architecture
diagram is directly visible in the output.

---

## 6. Vocabulary

| Term | One line |
|---|---|
| **Cluster** | control plane + nodes, managed as one |
| **Node** | a machine that runs pods |
| **Pod** | smallest deployable unit; containers sharing network + storage |
| **ReplicaSet** | keeps N identical pods alive |
| **Deployment** | manages ReplicaSets, gives you rollouts and rollbacks |
| **DaemonSet** | one pod per node |
| **StatefulSet** | ordered pods with stable names and their own storage |
| **Service** | stable virtual IP + DNS name in front of a set of pods |
| **Ingress** | L7 HTTP routing rules into the cluster |
| **ConfigMap / Secret** | configuration and credentials, injected as env vars or files |
| **Namespace** | a scope for names, quotas and RBAC |
| **Controller** | a loop that drives actual state toward desired state |
