# 11 — Kubernetes Ingress, ConfigMaps & Secrets

Assignment: Ingress vs Ingress Controller, path-based vs host-based routing, and
ConfigMaps/Secrets in practice.

Manifests: [`01-configmap/`](01-configmap/) · [`02-secret/`](02-secret/) ·
[`03-ingress/`](03-ingress/) · [`04-full-demo/`](04-full-demo/) (one script that wires
all three together).

> **Evidence note** — manifests and commands are complete and ready to apply on the
> minikube setup from [section 08](../08-kubernetes-fundamentals/). Captured terminal
> output for the Kubernetes sections is not in this branch; sections 01–07 are the ones
> with screenshots.

---

## 1. Ingress vs Ingress Controller

* **Ingress** is an API object — a set of L7 routing *rules* (host, path, TLS, backend
  service). It is a blueprint and nothing more. Create one in a cluster with no
  controller and absolutely nothing happens: no IP is assigned, no traffic moves.
* **Ingress Controller** is the software that actually does the work — NGINX, Traefik,
  HAProxy, Envoy/Contour, or a cloud ALB controller. It runs as pods in the cluster,
  watches the API server for Ingress objects, rewrites its own proxy configuration to
  match, and terminates the real connections.

One line: **the Ingress is the config, the controller is the proxy that reads it.** The
controller is itself exposed by a single `LoadBalancer` or `NodePort` Service — which is
the point: one external IP for the whole cluster instead of one per Service (section 10
§3). `ingressClassName: nginx` is what binds a rule to a specific controller when a
cluster runs more than one.

```bash
minikube addons enable ingress
kubectl -n ingress-nginx get pods,svc     # the controller, and its single entry point
kubectl get ingressclass
```

---

## 2. Path-based vs host-based routing

| | **Path-based** | **Host-based** |
|---|---|---|
| Routes on | the URL path | the HTTP `Host` header |
| Example | `example.com/api` → api-svc, `example.com/shop` → shop-svc | `api.example.com` → api-svc, `shop.example.com` → shop-svc |
| DNS needed | one record | one record **per** hostname |
| TLS | one certificate | a cert per host, or one wildcard |
| Typical use | one product, several backends | multi-tenant, or separate public products |

Manifests: [`03-ingress/path-based.yaml`](03-ingress/path-based.yaml) and
[`03-ingress/host-based.yaml`](03-ingress/host-based.yaml). They can be combined — hosts
at the top level, paths within each host — and [`03-ingress/tls.yaml`](03-ingress/tls.yaml)
adds HTTPS termination at the controller.

**`pathType` matters.** `Prefix` matches whole path segments (`/api` matches `/api/users`
but not `/apifoo`), `Exact` matches the full path only, and `ImplementationSpecific`
hands interpretation to the controller — which is what the regex capture groups in
`path-based.yaml` need, paired with `nginx.ingress.kubernetes.io/rewrite-target`.
Without that rewrite the backend receives `/api/users` instead of `/users` and returns
404, which is the most common path-routing mistake.

---

## 3. ConfigMaps

Non-secret configuration, kept out of the image so the same image ships to every
environment. [`01-configmap/app-config.yaml`](01-configmap/app-config.yaml) holds both
shapes: individual keys, and a whole `app.properties` file.

Three ways to consume it, all in [`01-configmap/pod-env.yaml`](01-configmap/pod-env.yaml):

| Method | Field | Updates without restart? |
|---|---|---|
| one key → one env var | `env[].valueFrom.configMapKeyRef` | **no** |
| every key → env vars | `envFrom.configMapRef` | **no** |
| keys → files | `volumes.configMap` | **yes** (the kubelet refreshes the mount) |

```bash
kubectl apply -f 01-configmap/app-config.yaml
kubectl create configmap app-config-2 --from-literal=KEY=value --from-file=app.properties
kubectl get configmap app-config -o yaml
kubectl apply -f 01-configmap/pod-env.yaml
kubectl logs config-consumer                 # env vars, then the mounted file
```

Env vars are read once at process start, so editing the ConfigMap does **not** reach a
running container — that needs `kubectl rollout restart deploy/<name>`. Mounted files do
update in place, eventually, which is why config you expect to change belongs in a
volume.

---

## 4. Secrets

Same mechanics, different object — and **base64 is encoding, not encryption**.

```bash
kubectl apply -f 02-secret/db-secret.yaml
kubectl create secret generic db2 --from-literal=DB_PASSWORD=S3cur3-Pa55w0rd
kubectl get secret db-secret -o jsonpath={.data.DB_PASSWORD} | base64 -d ; echo
kubectl apply -f 02-secret/pod-secret.yaml
kubectl exec secret-consumer -- sh -c 'echo $DB_USER; ls -l /etc/db'
```

Anyone with `get secret` RBAC can decode a Secret in one command, and the value sits in
plain etcd unless encryption-at-rest is configured. Practical consequences: restrict
RBAC, enable etcd encryption, prefer an external store (Vault, Sealed Secrets, a cloud
secrets manager) for anything real, and never commit a populated Secret to git.

**The base64 gotcha:** writing the `data` field by hand with `echo "pass" | base64` bakes
a **trailing newline** into the value, so the password looks correct and every login
fails. Use `echo -n`, or better, use `stringData` (as
[`02-secret/db-secret.yaml`](02-secret/db-secret.yaml) does) and let Kubernetes do the
encoding, or `kubectl create secret --from-literal`.

---

## 5. Full demo — [`04-full-demo/`](04-full-demo/)

[`run-demo.sh`](04-full-demo/run-demo.sh) enables the ingress controller, applies the
ConfigMap and Secret, brings up three nginx backends whose pages come from the
ConfigMap, applies the path-based Ingress, adds the host to `/etc/hosts`, then curls
`/api`, `/shop` and `/` to prove each lands on a different Service — and finally shows
the config and secret values from inside the pod.

```bash
cd 04-full-demo && ./run-demo.sh      # ./cleanup.sh removes everything
```

---

## 6. Debugging

```bash
kubectl describe ingress <name>                     # rules, and the assigned ADDRESS
kubectl get ingress                                 # ADDRESS empty -> no controller
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller
kubectl get svc <backend-svc>                       # 503 is usually the backend
```

`404` from the controller means no rule matched (wrong host, wrong `pathType`, or a
missing rewrite). `503` means the rule matched but the backend Service has no ready
endpoints — a section 10 §7 problem. An empty `ADDRESS` means no controller is watching
this `ingressClassName` at all.
