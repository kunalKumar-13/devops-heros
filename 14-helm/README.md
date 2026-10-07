# Session 15 — Helm

**Kunal Kumar · Roll No. 24BCS10027**

The mini-project from the session: package the notes app as a Helm chart, then
take it through a release's whole life. Lint, render, install with development
values, upgrade to production values, push a bad upgrade on purpose, roll back,
clean up.

Everything was run on a real Kubernetes cluster (kind, inside GitHub Actions) by
[`lab.sh`](lab.sh). The full, unedited transcript is in
[`session-output.txt`](session-output.txt).

---

## The chart

```text
notes-chart/
├── Chart.yaml            name, chart version 0.1.0, app version 1.0.0
├── values.yaml           development defaults: 1 replica, nginx 1.26-alpine
├── values-prod.yaml      production overrides: 3 replicas, nginx 1.27-alpine
└── templates/
    ├── _helpers.tpl      shared labels (app, environment, chart, managed-by)
    ├── configmap.yaml    the page nginx serves, built from values
    ├── deployment.yaml   replicas/image from values, readiness probe, page mounted from the ConfigMap
    └── service.yaml      NodePort 30090
```

The page the app serves is rendered from values (environment, release name,
revision, image, the notes list), so every upgrade and rollback is visible in
the app itself, not just in `helm history`.

`deployment.yaml` carries a `checksum/config` annotation: the SHA-256 of the
rendered ConfigMap. When the page content changes, the hash changes, the pod
template changes, and Kubernetes rolls the pods. Without it, a ConfigMap-only
change would not restart anything and the pods would keep serving the old page.

## Commands, in order

```bash
helm lint notes-chart                                  # also with -f notes-chart/values-prod.yaml
helm template notes-dev notes-chart                    # render locally, nothing touches the cluster
helm install notes-dev notes-chart --wait              # revision 1: development values
helm upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml --wait          # revision 2
helm history notes-dev
helm upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml \
     --set image.tag=9.99-doesnotexist --wait --timeout 60s                        # revision 3: fails
helm rollback notes-dev 2 --wait                       # revision 4: a copy of revision 2
helm get values notes-dev --revision 2
helm uninstall notes-dev
```

## Things worth knowing

**Chart vs release vs revision.** The chart is the package (templates plus
default values). A release is one installed copy of it, with a name
(`notes-dev`). Every install, upgrade or rollback creates a new revision of
that release. Helm keeps each one as a Secret in the namespace, which is how
`history` and `rollback` work.

**values.yaml and -f.** `values.yaml` holds the defaults; `-f values-prod.yaml`
is merged on top, and `--set` on top of that. Only what differs needs to be in
the prod file.

**Why `--wait` matters.** Without it, `helm upgrade` reports success as soon as
Kubernetes accepts the objects, even if the new pods never start. With `--wait`
the bad image upgrade was marked `failed` after the timeout, which is what you
want a pipeline to see.

**The bad upgrade didn't take the app down.** The Deployment does a rolling
update: the new pod got stuck in `ImagePullBackOff`, so the old pods were never
removed and the app kept serving the production page throughout.

**Rollback creates a new revision.** `helm rollback notes-dev 2` did not delete
revision 3. It created revision 4 with revision 2's manifest, so the history
still shows what happened.

---

## What happened when it ran

Every command below ran in GitHub Actions on a fresh machine; these are verbatim excerpts of the transcript.

Run: <https://github.com/kunalKumar-13/devops-heros/actions/runs/37657639033>

**Verified results: 9 passed, 0 failed** (the checks the lab script makes; the job fails if any of them fail):

```text
  PASS  the chart lints cleanly with dev and prod values
  PASS  install: revision 1 deployed
  PASS  install: 1 replica of nginx:1.26-alpine, page says development
  PASS  upgrade: revision 2 deployed
  PASS  upgrade: 3 replicas of nginx:1.27-alpine, page says production
  PASS  bad upgrade: revision 3 is marked failed
  PASS  rollback: revision 4 deployed
  PASS  rollback: back on nginx:1.27-alpine with 3 ready replicas
  PASS  uninstall: nothing labelled app=notes-dev is left
```

**4. Install (development values)**

```console
kunal@kind-lab:~$ helm install notes-dev notes-chart --wait --timeout 3m
NAME: notes-dev
LAST DEPLOYED: Wed Oct  7 17:28:45 2026
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None

kunal@kind-lab:~$ kubectl get pods -l app=notes-dev
NAME                                READY   STATUS    RESTARTS   AGE
notes-dev-deploy-5bf4b5db4b-jmwwm   1/1     Running   0          2s

kunal@kind-lab:~$ kubectl get services notes-dev-svc
NAME            TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
notes-dev-svc   NodePort   10.96.45.44   <none>        80:30090/TCP   2s

kunal@kind-lab:~$ kubectl get configmaps notes-dev-config
NAME               DATA   AGE
notes-dev-config   3      2s

>>> the page the app is serving now:

kunal@kind-lab:~$ curl -s http://notes-dev-svc
environment: development | release: notes-dev | revision: 1 | image: nginx:1.26-alpine Helm turns a directory of templates into a versioned release values.yaml is the default; -f values-prod.yaml overrides it helm rollback restores any earlier revision notes-app notes-app environment: development | release: notes-dev | revision: 1 | image: nginx:1.26-alpine
```

**5. Upgrade to production values**

```console
kunal@kind-lab:~$ helm upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml --wait --timeout 3m
Release "notes-dev" has been upgraded. Happy Helming!
NAME: notes-dev
LAST DEPLOYED: Wed Oct  7 17:28:52 2026
NAMESPACE: default
STATUS: deployed
REVISION: 2
TEST SUITE: None

kunal@kind-lab:~$ kubectl get pods -l app=notes-dev
NAME                                READY   STATUS    RESTARTS   AGE
notes-dev-deploy-57cf78c576-fzsv6   1/1     Running   0          4s
notes-dev-deploy-57cf78c576-msrdd   1/1     Running   0          3s
notes-dev-deploy-57cf78c576-zwh9z   1/1     Running   0          4s

kunal@kind-lab:~$ curl -s http://notes-dev-svc
environment: production | release: notes-dev | revision: 2 | image: nginx:1.27-alpine Helm turns a directory of templates into a versioned release values.yaml is the default; -f values-prod.yaml overrides it helm rollback restores any earlier revision notes-app notes-app environment: production | release: notes-dev | revision: 2 | image: nginx:1.27-alpine
```

**7. A bad upgrade: an image tag that does not exist**

```console
>>> --wait makes Helm wait for the rollout, so a broken image fails the release instead of quietly succeeding

kunal@kind-lab:~$ helm upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml --set image.tag=9.99-doesnotexist --wait --timeout 60s
Error: UPGRADE FAILED: context deadline exceeded

kunal@kind-lab:~$ helm history notes-dev
REVISION	UPDATED                 	STATUS    	CHART            	APP VERSION	DESCRIPTION                                          
1       	Wed Oct  7 17:28:45 2026	superseded	notes-chart-0.1.0	1.0.0      	Install complete                                     
2       	Wed Oct  7 17:28:52 2026	deployed  	notes-chart-0.1.0	1.0.0      	Upgrade complete                                     
3       	Wed Oct  7 17:29:00 2026	failed    	notes-chart-0.1.0	1.0.0      	Upgrade "notes-dev" failed: context deadline exceeded

kunal@kind-lab:~$ kubectl get pods -l app=notes-dev
NAME                                READY   STATUS         RESTARTS   AGE
notes-dev-deploy-57cf78c576-fzsv6   1/1     Running        0          68s
notes-dev-deploy-57cf78c576-msrdd   1/1     Running        0          67s
notes-dev-deploy-57cf78c576-zwh9z   1/1     Running        0          68s
notes-dev-deploy-8675d5688c-v2tww   0/1     ErrImagePull   0          60s

>>> the old ReplicaSet's pods are still serving: a failed rolling update never removes working pods before new ones are ready
```

**8. Roll back to revision 2**

```console
kunal@kind-lab:~$ helm rollback notes-dev 2 --wait --timeout 3m
Rollback was a success! Happy Helming!

kunal@kind-lab:~$ helm history notes-dev
REVISION	UPDATED                 	STATUS    	CHART            	APP VERSION	DESCRIPTION                                          
1       	Wed Oct  7 17:28:45 2026	superseded	notes-chart-0.1.0	1.0.0      	Install complete                                     
2       	Wed Oct  7 17:28:52 2026	superseded	notes-chart-0.1.0	1.0.0      	Upgrade complete                                     
3       	Wed Oct  7 17:29:00 2026	failed    	notes-chart-0.1.0	1.0.0      	Upgrade "notes-dev" failed: context deadline exceeded
4       	Wed Oct  7 17:30:00 2026	deployed  	notes-chart-0.1.0	1.0.0      	Rollback to 2                                        

kunal@kind-lab:~$ kubectl rollout status deployment/notes-dev-deploy --timeout=180s
deployment "notes-dev-deploy" successfully rolled out

kunal@kind-lab:~$ kubectl get pods -l app=notes-dev
NAME                                READY   STATUS    RESTARTS   AGE
notes-dev-deploy-57cf78c576-fzsv6   1/1     Running   0          70s
notes-dev-deploy-57cf78c576-msrdd   1/1     Running   0          69s
notes-dev-deploy-57cf78c576-zwh9z   1/1     Running   0          70s

kunal@kind-lab:~$ curl -s http://notes-dev-svc
environment: production | release: notes-dev | revision: 2 | image: nginx:1.27-alpine
```

