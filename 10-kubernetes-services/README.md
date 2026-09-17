# 10 — Kubernetes Networking & Services

Assignment: the five Service types — ClusterIP, NodePort, LoadBalancer, ExternalName and
Headless — plus how in-cluster DNS resolves them.

One shared backend ([`00-backend-deployment.yaml`](00-backend-deployment.yaml), 3 pods of
`echoserver`, which prints the pod name it answered from) sits behind all five.

> **Evidence note** — manifests and commands are complete and ready to apply on the
> minikube setup from [section 08](../08-kubernetes-fundamentals/#5-lab-environment-used-for-sections-0911).
> Captured terminal output for the Kubernetes sections is not in this branch; sections
> 01–07 are the ones with screenshots.

---

## Why Services exist at all

Pod IPs are **ephemeral**. A pod restarts, gets rescheduled, is scaled away — new IP
every time. Nothing can hardcode a pod IP and keep working.

A Service is a stable **name + virtual IP** in front of a *set* of pods chosen by label
selector. The set of backing IPs is maintained for you: the EndpointSlice controller
watches pods matching the selector and keeps their IPs in an EndpointSlice, and
`kube-proxy` on every node programs the kernel (iptables by default) to DNAT the virtual
IP to one of the **ready** ones. Readiness matters — a pod failing its readiness probe is
removed from the endpoint list and stops receiving traffic without being deleted.

```
     ClusterIP ────── in-cluster only
         │
     NodePort ─────── ClusterIP + <node-ip>:30080 on every node
         │
   LoadBalancer ───── NodePort + a cloud L4 load balancer
```

Each type is a **superset** of the one above it.

| Type | Virtual IP | Reachable from | Typical use |
|---|---|---|---|
| **ClusterIP** | yes | inside the cluster only | internal service-to-service (default) |
| **NodePort** | yes | outside, via `<node-ip>:3xxxx` | dev/demo, or behind your own LB |
| **LoadBalancer** | yes | outside, via a provisioned LB IP | production entry point on a cloud |
| **ExternalName** | no | DNS CNAME only | give an external dependency an in-cluster name |
| **Headless** | none (`None`) | pod IPs direct, via DNS | StatefulSet members, client-side LB |

---

## 1. ClusterIP — [`01-clusterip/`](01-clusterip/)

The default. A virtual IP that exists only inside the cluster; there is no route to it
from your laptop. `port` is what the Service listens on, `targetPort` is the port on the
pod.

```bash
kubectl apply -f 00-backend-deployment.yaml
kubectl apply -f 01-clusterip/service.yaml
kubectl apply -f 01-clusterip/client-pod.yaml

kubectl get svc web-clusterip                    # CLUSTER-IP set, EXTERNAL-IP <none>
kubectl get endpointslice -l kubernetes.io/service-name=web-clusterip
                                                 # the three ready pod IPs

# reach it by DNS name from inside the cluster
kubectl exec client -- curl -s http://web-clusterip/ | head -20

# load balancing: repeat and watch the responding pod name change
for i in $(seq 1 6); do
  kubectl exec client -- curl -s http://web-clusterip/ | grep -i hostname
done
```

Scale the Deployment to 0 and `kubectl get endpointslice` shows **no endpoints** — the
Service still exists, but `curl` now fails immediately. That is the single most common
"my Service is broken" cause, and it is almost always a **selector mismatch** or pods
failing readiness, not the Service itself.

---

## 2. NodePort — [`02-nodeport/`](02-nodeport/)

Everything ClusterIP does, plus the same port opened on **every** node, in the range
`30000–32767`.

```bash
kubectl apply -f 02-nodeport/service.yaml
kubectl get svc web-nodeport                     # PORT(S) shows 80:30080/TCP

curl -s http://$(minikube ip):30080/ | head -20  # from the VM, no port-forward
minikube service web-nodeport --url              # the URL minikube would open
```

Fine for a lab, poor as a production front door: the port range is non-standard, the
client must know a node IP, and nothing balances across nodes unless you put your own
load balancer in front — which is what the next type automates.

---

## 3. LoadBalancer — [`03-loadbalancer/`](03-loadbalancer/)

NodePort plus a request to the cloud provider (via the cloud-controller-manager) for a
real external L4 load balancer.

```bash
kubectl apply -f 03-loadbalancer/service.yaml
kubectl get svc web-lb                           # EXTERNAL-IP: <pending>
```

On minikube `EXTERNAL-IP` stays **`<pending>` forever** — and that is correct behaviour,
not a bug. There is no cloud controller to answer the request (see section 08 §2).
`minikube tunnel` fakes one:

```bash
sudo minikube tunnel &                           # keep running in another terminal
kubectl get svc web-lb                           # EXTERNAL-IP now assigned
curl -s http://<external-ip>/ | head -20
```

On a real cloud this is one cloud LB per Service, which gets expensive fast — the usual
production pattern is **one** LoadBalancer in front of an ingress controller, and
everything else behind Ingress rules (section 11).

---

## 4. ExternalName — [`04-externalname/`](04-externalname/)

The odd one out: no selector, no endpoints, no virtual IP and no proxying. CoreDNS
simply returns a **CNAME**.

```bash
kubectl apply -f 04-externalname/service.yaml
kubectl get svc external-db                      # TYPE ExternalName, no CLUSTER-IP

kubectl exec client -- nslookup external-db.default.svc.cluster.local
# → canonical name = example.com
```

Use it to give an out-of-cluster dependency a stable in-cluster name: the app always
talks to `external-db`, and moving that database from RDS to in-cluster later is a
one-line Service change with no application redeploy. Caveats: it only rewrites DNS, so
TLS certificates and HTTP `Host` headers still carry the *real* target name, and it does
nothing for a dependency addressed by IP.

---

## 5. Headless — [`05-headless/`](05-headless/)

`clusterIP: None`. No virtual IP, no kube-proxy rules — a DNS query for the Service name
returns the **A records of every ready pod**, and the client chooses.

```bash
kubectl apply -f 05-headless/service.yaml
kubectl get svc web-headless                     # CLUSTER-IP: None

kubectl exec client -- nslookup web-headless.default.svc.cluster.local
# → three addresses, one per pod, instead of one virtual IP
```

Two reasons to want this: **StatefulSet members** need to address each other
individually (`web-0.web-headless…`, section 09 §5), and some clients — gRPC, Kafka,
database drivers with their own connection pools — want the real endpoint list so they
can do their own load balancing and keep long-lived connections. A normal ClusterIP is
a poor fit for gRPC, because a single long-lived HTTP/2 connection gets DNAT'd to one
pod and stays pinned there.

---

## 6. Service DNS and the FQDN

CoreDNS gives every Service a name in a fixed pattern:

```
<service>.<namespace>.svc.cluster.local
   │           │        │      └── cluster domain
   │           │        └───────── "it is a service"
   │           └────────────────── namespace
   └────────────────────────────── service name
```

A pod's `/etc/resolv.conf` carries a search list, so the short forms work by suffixing:

| From a pod in namespace `default` | Resolves to |
|---|---|
| `web-clusterip` | `web-clusterip.default.svc.cluster.local` |
| `web-clusterip.default` | same |
| `web-clusterip.default.svc` | same |
| `web-clusterip.prod` | the `web-clusterip` Service in namespace **prod** |

Cross-namespace calls therefore need at least `<service>.<namespace>` — the bare name
only ever finds a Service in the caller's own namespace, which is a routine source of
"works in staging, not in prod" bugs. Named ports additionally get SRV records
(`_http._tcp.web-clusterip.default.svc.cluster.local`).

```bash
kubectl exec client -- cat /etc/resolv.conf
kubectl exec client -- nslookup web-clusterip
kubectl -n kube-system get pods -l k8s-app=kube-dns     # CoreDNS itself
```

---

## 7. Debugging a Service that "does not work"

```bash
kubectl get endpointslice -l kubernetes.io/service-name=<svc>   # empty? it is the selector or readiness
kubectl describe svc <svc>                                      # Selector vs the pods' actual labels
kubectl get pods --show-labels
kubectl get pods -o wide                                        # are they Ready, not just Running?
kubectl exec client -- nslookup <svc>                           # DNS resolving at all?
kubectl exec client -- curl -sv http://<svc>:<port>/            # then connectivity
kubectl -n kube-system logs -l k8s-app=kube-dns                 # CoreDNS errors
```

In order, the causes: **selector does not match the pod labels** → **`targetPort` is not
the port the container listens on** → **readiness probe failing, so no endpoints** →
**wrong namespace in the DNS name** → only then anything cluster-level.

---

## Cleanup

```bash
kubectl delete -f 05-headless/ -f 04-externalname/ -f 03-loadbalancer/ \
                 -f 02-nodeport/ -f 01-clusterip/ -f 00-backend-deployment.yaml
```
