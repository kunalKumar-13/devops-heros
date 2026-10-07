# Session 14 — Kubernetes Troubleshooting

**Kunal Kumar · Roll No. 24BCS10027**

The troubleshooting challenge from the session: deploy a working app, then break
it on purpose and find each fault the way you would in production, from the
symptom back to the root cause. Five faults: a bad image, a Service selector
mismatch, a crash loop, an unschedulable pod and an out-of-memory kill.

Everything was run on a real Kubernetes cluster (kind, inside GitHub Actions) by
[`lab.sh`](lab.sh). The full, unedited transcript is in
[`session-output.txt`](session-output.txt).

---

## Files

| File | Fault |
|---|---|
| [`manifests/01-app.yaml`](manifests/01-app.yaml) | the healthy baseline: `troubleshooting-app` + `troubleshooting-service` |
| [`manifests/02-broken-image.yaml`](manifests/02-broken-image.yaml) | `project-broken-pod`: an image tag that does not exist |
| [`manifests/03-broken-service.yaml`](manifests/03-broken-service.yaml) | Service selector `app: wrong-app` |
| [`manifests/04-crashloop.yaml`](manifests/04-crashloop.yaml) | process exits with an error |
| [`manifests/05-pending.yaml`](manifests/05-pending.yaml) | requests 64 CPUs |
| [`manifests/06-oomkilled.yaml`](manifests/06-oomkilled.yaml) | allocates 200MB with a 32Mi limit |

---

## Task 7: the broken pod

`project-broken-pod` uses the image `nginx:1.27-doesnotexist`. I did not touch
the YAML until I had found the cause: first `get`, then `describe`, then the
Events.

**Q1. What is the Pod status?**
`0/1 ImagePullBackOff` (it shows `ErrImagePull` for the first few seconds, then
`ImagePullBackOff` once the kubelet starts backing off between retries).

**Q2. What is the actual error?**
From the Events:
`Failed to pull image "nginx:1.27-doesnotexist": ... docker.io/library/nginx:1.27-doesnotexist: not found`

**Q3. Which command helped you find the reason?**
`kubectl describe pod project-broken-pod`, the Events section at the bottom.
`kubectl logs` was no use here: it only says the container is "waiting to
start", because no container ever ran.

**Q4. What is wrong with the image?**
The repository `nginx` exists but the tag `1.27-doesnotexist` does not, so the
registry answers "not found". The node has nothing to start.

**Q5. How would you fix it?**
Change the image to a tag that exists (I used `nginx:1.27-alpine`) and apply it
again. A pod's image can't be fixed in place on a bare Pod, so delete and
recreate it; in a Deployment you would just change the image and let it roll
out. The lab shows the fixed pod reaching `1/1 Running`.

## Task 11: troubleshooting table

| Problem | What I saw | Command I used | Root cause | Fix |
| :--- | :--- | :--- | :--- | :--- |
| **Broken Pod** (crash loop) | `CrashLoopBackOff`, restart count going up | `kubectl logs crashloop --previous`, `kubectl describe pod` | the process exits with code 1 on start (`FATAL: config file /etc/app.conf not found`) | give the app the config it needs (a ConfigMap mounted at that path) or fix the command; once it stays up the restarts stop |
| **Service Problem** | Service exists, `ENDPOINTS <none>`, curl through it fails (`HTTP 000`) | `kubectl get endpoints`, `kubectl get pods --show-labels`, `kubectl describe service` | selector `app=wrong-app`, but the pods are labelled `app=troubleshooting-app` | set the selector back to `app: troubleshooting-app`; endpoints came back and curl returned `HTTP 200` |
| **Image Problem** | `ErrImagePull`, then `ImagePullBackOff`, no logs | `kubectl describe pod project-broken-pod` (Events) | tag `nginx:1.27-doesnotexist` does not exist in the registry | use a real tag (`nginx:1.27-alpine`) |
| Pending (extra) | `Pending` forever, no node assigned | `kubectl describe pod pending` (Events) | requests 64 CPUs: `0/2 nodes are available: 1 Insufficient cpu, 1 node(s) had untolerated taint(s)` | request what the app really needs, or add bigger nodes |
| OOMKilled (extra) | status `OOMKilled`, exit code 137 | `kubectl get pod -o jsonpath=...state.terminated.reason`, `kubectl describe pod` | allocates ~200MB with a 32Mi memory limit | raise the limit to what the app uses, or fix the memory use |

## Task 12: README questions

**1. What does `kubectl get` tell us?**
A one-line summary per object: for pods that is ready count, status, restarts
and age. It is the first look, it tells you *that* something is wrong and
roughly what kind of wrong.

**2. What is the difference between `get` and `describe`?**
`get` is the summary row. `describe` is the full picture of one object: its
spec, conditions, container states with exit codes, mounted volumes, and most
useful of all, the recent Events. `get` says `ImagePullBackOff`, `describe`
says which image and that the registry answered "not found".

**3. Why do we use `kubectl logs`?**
To see what the application itself printed to stdout/stderr. It is how you find
out *why* a running or crashed container failed. `--previous` shows the run
before the last restart, which is the one you want for a crash loop. It can't
help when the container never started (image or scheduling problems).

**4. When would you use `kubectl exec`?**
When the pod is running but something inside is off and you need to look
around: check a config file or env var was mounted, `curl localhost` to see if
the app answers, test DNS or reach another Service from inside the pod's
network. I used it to curl nginx on `localhost` from inside the pod.

**5. What does `CrashLoopBackOff` mean?**
The container starts, exits (crashes), gets restarted, crashes again, and the
kubelet waits a bit longer before each restart (10s, 20s, 40s ... up to 5
minutes). The problem is in the app or its config, so the answer is usually in
`kubectl logs --previous`.

**6. What does `ImagePullBackOff` mean?**
The node could not pull the image, and is now waiting before trying again.
Usual causes: wrong name or tag, a private registry with no pull secret, or the
node can't reach the registry. Nothing ran, so the Events are the only clue.

**7. Why can a Pod remain `Pending`?**
The scheduler can't find a node for it. Common reasons: not enough CPU or
memory for its requests (my lab: 64 CPUs), a nodeSelector/affinity no node
matches, taints it doesn't tolerate, or a PVC that can't be bound. `describe`
shows a `FailedScheduling` event that names the reason.

**8. Why can a Service have no endpoints?**
Because its selector matches no *ready* pod. Either the labels don't match (my
lab: `app=wrong-app`), the pods don't exist in that namespace, or they exist
but are failing their readiness probe.

**9. What is the relationship between a Service selector and Pod labels?**
The Service doesn't point at pods by name. It keeps a live list of every ready
pod whose labels match its selector, and those pods' IPs are its endpoints. If
one character differs, the Service is just an IP with nothing behind it.

**10. What is Kubernetes DNS?**
CoreDNS, running in the cluster, gives every Service a name:
`<service>.<namespace>.svc.cluster.local`, which resolves to the Service's
ClusterIP. Pods can just use `troubleshooting-service` inside the same
namespace. In the lab, `nslookup` from a busybox pod returned the Service's
ClusterIP.

---

## The order I check things in

```bash
kubectl get pods                         # what state is it in?
kubectl describe pod <pod>               # Events at the bottom: scheduling, pulling, probe failures
kubectl logs <pod> [--previous]          # what did the app itself say? --previous for the crashed run
kubectl exec -it <pod> -- sh             # look from inside: files, env, network
kubectl get events --sort-by=.lastTimestamp

# Service problems
kubectl get endpoints <service>          # empty = the selector matches no ready pod
kubectl describe service <service>       # compare Selector with the pods' labels
kubectl get pods --show-labels
nslookup <service>                       # from a pod: does the name resolve?
```

The key habit: **`describe` events for anything before the container starts**
(scheduling, image pull), **`logs` for anything after** (the app crashing). A pod
in `ImagePullBackOff` has no logs at all, because no container ever ran.

---

## What happened when it ran

Every command below ran in GitHub Actions on a fresh machine; these are verbatim excerpts of the transcript.

Run: <https://github.com/kunalKumar-13/devops-heros/actions/runs/37657639033>

**Verified results: 14 passed, 0 failed** (the checks the lab script makes; the job fails if any of them fail):

```text
  PASS  inside the pod, nginx answers on localhost
  PASS  baseline: the Service answers
  PASS  baseline: the Service has endpoints
  PASS  bad image: pod is stuck in ErrImagePull / ImagePullBackOff
  PASS  bad image fixed: a pod with a real tag becomes Ready
  PASS  broken selector: the Service has no endpoints
  PASS  selector fixed: endpoints are back
  PASS  selector fixed: the Service answers again
  PASS  the Service DNS name resolves to the Service ClusterIP
  PASS  crash loop: the container has been restarted
  PASS  crash loop: the logs show why (FATAL config error)
  PASS  pending: PodScheduled is false with reason Unschedulable
  PASS  out of memory: terminated with reason OOMKilled
  PASS  exec works inside a healthy pod
```

**4. Broken pod: bad image**

```console
kunal@kind-lab:~$ kubectl apply -f manifests/02-broken-image.yaml
pod/project-broken-pod created

kunal@kind-lab:~$ kubectl get pod project-broken-pod
NAME                 READY   STATUS             RESTARTS   AGE
project-broken-pod   0/1     ImagePullBackOff   0          25s

kunal@kind-lab:~$ kubectl describe pod project-broken-pod | sed -n '/Events:/,$p'
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  25s                default-scheduler  Successfully assigned default/project-broken-pod to devops-worker
  Normal   BackOff    25s                kubelet            spec.containers{nginx}: Back-off pulling image "nginx:1.27-doesnotexist"
  Warning  Failed     25s                kubelet            spec.containers{nginx}: Error: ImagePullBackOff
  Normal   Pulling    10s (x2 over 25s)  kubelet            spec.containers{nginx}: Pulling image "nginx:1.27-doesnotexist"
  Warning  Failed     10s (x2 over 25s)  kubelet            spec.containers{nginx}: Failed to pull image "nginx:1.27-doesnotexist": rpc error: code = NotFound desc = failed to pull and unpack image "docker.io/library/nginx:1.27-doesnotexist": failed to resolve reference "docker.io/library/nginx:1.27-doesnotexist": docker.io/library/nginx:1.27-doesnotexist: not found
  Warning  Failed     10s (x2 over 25s)  kubelet            spec.containers{nginx}: Error: ErrImagePull

kunal@kind-lab:~$ kubectl logs project-broken-pod || true
Error from server (BadRequest): container "nginx" in pod "project-broken-pod" is waiting to start: trying and failing to pull image

>>> no logs: the container never started, so the evidence is only in the events

kunal@kind-lab:~$ kubectl delete pod project-broken-pod
pod "project-broken-pod" deleted from default namespace

>>> fix: use a tag that exists

kunal@kind-lab:~$ kubectl run fixed-image --image=nginx:1.27-alpine && kubectl wait --for=condition=Ready pod/fixed-image --timeout=120s
pod/fixed-image created
[... 8 more lines in the full transcript ...]
```

**5. Service problem: selector does not match the pods**

```console
kunal@kind-lab:~$ kubectl apply -f manifests/03-broken-service.yaml
service/troubleshooting-service configured

kunal@kind-lab:~$ kubectl get service troubleshooting-service
NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
troubleshooting-service   ClusterIP   10.96.189.133   <none>        80/TCP    36s

kunal@kind-lab:~$ kubectl get endpoints troubleshooting-service
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
NAME                      ENDPOINTS   AGE
troubleshooting-service   <none>      36s

kunal@kind-lab:~$ kubectl run curl-broken --rm -i -q --restart=Never --image=curlimages/curl:8.10.1 -- curl -s -m 5 -o /dev/null -w 'HTTP %{http_code}\n' http://troubleshooting-service || echo 'request failed: nothing behind the Service'
HTTP 000
pod default/curl-broken terminated (Error)
request failed: nothing behind the Service

>>> root cause: compare the pod labels with the Service selector

kunal@kind-lab:~$ kubectl get pods --show-labels -l app=troubleshooting-app
NAME                                   READY   STATUS    RESTARTS   AGE   LABELS
troubleshooting-app-794bc67b9c-7gkxs   1/1     Running   0          38s   app=troubleshooting-app,pod-template-hash=794bc67b9c
troubleshooting-app-794bc67b9c-jzm7f   1/1     Running   0          38s   app=troubleshooting-app,pod-template-hash=794bc67b9c

kunal@kind-lab:~$ kubectl describe service troubleshooting-service | grep -E 'Selector|Endpoints'
Selector:                 app=wrong-app
Endpoints:                

>>> fix: put the selector back to app=troubleshooting-app

kunal@kind-lab:~$ kubectl apply -f manifests/01-app.yaml
deployment.apps/troubleshooting-app unchanged
service/troubleshooting-service configured

kunal@kind-lab:~$ kubectl get endpoints troubleshooting-service
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
NAME                      ENDPOINTS                       AGE
troubleshooting-service   10.244.1.74:80,10.244.1.75:80   42s

kunal@kind-lab:~$ kubectl run curl-fixed --rm -i -q --restart=Never --image=curlimages/curl:8.10.1 -- curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://troubleshooting-service
[... 1 more lines in the full transcript ...]
```

**7. CrashLoopBackOff**

```console
kunal@kind-lab:~$ kubectl apply -f manifests/04-crashloop.yaml
pod/crashloop created

kunal@kind-lab:~$ kubectl get pod crashloop
NAME        READY   STATUS   RESTARTS      AGE
crashloop   0/1     Error    3 (32s ago)   45s

kunal@kind-lab:~$ kubectl logs crashloop
starting
FATAL: config file /etc/app.conf not found

kunal@kind-lab:~$ kubectl describe pod crashloop | grep -E 'State|Reason|Exit Code|Restart Count|Back-off' | head -10
    State:          Terminated
      Reason:       Error
      Exit Code:    1
    Last State:     Terminated
      Reason:       Error
      Exit Code:    1
    Restart Count:  3
  Type     Reason     Age               From               Message
  Warning  BackOff    8s (x3 over 44s)  kubelet            spec.containers{app}: Back-off restarting failed container app in pod crashloop_default(3c988b18-688d-488a-a660-058bd7f58ed2)

kunal@kind-lab:~$ kubectl delete pod crashloop --wait=false
pod "crashloop" deleted from default namespace
```

**8. Pending: the scheduler cannot place the pod**

```console
kunal@kind-lab:~$ kubectl apply -f manifests/05-pending.yaml
pod/pending created

kunal@kind-lab:~$ kubectl get pod pending
NAME      READY   STATUS    RESTARTS   AGE
pending   0/1     Pending   0          10s

kunal@kind-lab:~$ kubectl describe pod pending | sed -n '/Events:/,$p'
Events:
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  10s   default-scheduler  0/2 nodes are available: 1 Insufficient cpu, 1 node(s) had untolerated taint(s). preemption: 0/2 nodes are available: 2 Preemption is not helpful for scheduling.

kunal@kind-lab:~$ kubectl delete pod pending --wait=false
pod "pending" deleted from default namespace
```

**9. OOMKilled: the container exceeds its memory limit**

```console
kunal@kind-lab:~$ kubectl apply -f manifests/06-oomkilled.yaml
pod/oomkilled created

kunal@kind-lab:~$ kubectl get pod oomkilled
NAME        READY   STATUS      RESTARTS   AGE
oomkilled   0/1     OOMKilled   0          25s

kunal@kind-lab:~$ kubectl get pod oomkilled -o jsonpath='reason={.status.containerStatuses[0].state.terminated.reason} exitCode={.status.containerStatuses[0].state.terminated.exitCode}'; echo
reason=OOMKilled exitCode=137

kunal@kind-lab:~$ kubectl delete pod oomkilled --wait=false
pod "oomkilled" deleted from default namespace
```

