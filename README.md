# DevOps Assignments — Kunal Kumar

**Kunal Kumar · Roll No. 24BCS10027**

Assignment branch of the [devops-heros](https://github.com/Nency-Ravaliya/devops-heros)
sessions. One folder per session, each with its own `README.md`.

| Session | Topic | Folder | How it was run |
|---|---|---|---|
| 1 & 2 | Linux Fundamentals | [`01-linux-basics/`](01-linux-basics/) | Ubuntu 26.04 VM, screenshots + [`logs/`](logs/) |
| 3 | Shell Scripting | [`02-shell-scripting/`](02-shell-scripting/) | Ubuntu VM |
| 4 | Networking Fundamentals | [`03-networking/`](03-networking/) | Ubuntu VM |
| 5 | Git & GitHub | [`04-git/`](04-git/) | Ubuntu VM |
| 6 | Docker Fundamentals | [`05-docker-hello-world/`](05-docker-hello-world/) | Ubuntu VM |
| 7 | Dockerfiles & Multi-stage Images | [`06-docker-multistage/`](06-docker-multistage/) | Ubuntu VM |
| 8 | Docker Networking & Volumes | [`07-docker-networking-volumes/`](07-docker-networking-volumes/) | Ubuntu VM |
| 9 | Kubernetes Fundamentals | [`08-kubernetes-fundamentals/`](08-kubernetes-fundamentals/) | kind cluster in CI, [`logs/k8s1.txt`](logs/k8s1.txt) |
| 10 | Pods, ReplicaSets & Deployments | [`09-kubernetes-workloads/`](09-kubernetes-workloads/) | kind in CI, [`logs/k8s2.txt`](logs/k8s2.txt) |
| 11 | Kubernetes Networking & Services | [`10-kubernetes-services/`](10-kubernetes-services/) | kind in CI, [`logs/k8s3.txt`](logs/k8s3.txt) |
| 12 | Ingress, ConfigMaps & Secrets | [`11-kubernetes-ingress-configmaps-secrets/`](11-kubernetes-ingress-configmaps-secrets/) | kind in CI, [`logs/k8s4.txt`](logs/k8s4.txt) |
| 13 | Storage, HPA & Probes | [`12-kubernetes-storage-hpa-probes/`](12-kubernetes-storage-hpa-probes/) | kind in CI |
| 14 | Kubernetes Troubleshooting | [`13-kubernetes-troubleshooting/`](13-kubernetes-troubleshooting/) | kind in CI |
| 15 | Helm | [`14-helm/`](14-helm/) | kind in CI |
| 16 | CI/CD with GitHub Actions | [`15-github-actions/`](15-github-actions/) | its own workflow |
| 17 | DevSecOps | [`16-devsecops/`](16-devsecops/) | its own workflow, image on GHCR |
| 18 | Terraform & IaC | [`17-terraform-iac/`](17-terraform-iac/) | Terraform against an AWS API emulator in CI |
| 19 | Cloud Networking with Terraform | [`18-cloud-terraform/`](18-cloud-terraform/) | same |
| 20 | Monitoring, Observability & GitOps | [`19-monitoring-observability-gitops/`](19-monitoring-observability-gitops/) | Docker Compose + Argo CD on kind in CI, screenshots |
| 21 | Final project | [kunalKumar-13/clinicflow](https://github.com/kunalKumar-13/clinicflow) | separate repository |

## How the evidence was produced

**Sessions 1–8** were done by hand on an Ubuntu 26.04 VM as user `kunal`. The
`console` blocks in those READMEs are captured terminal output, the
screenshots are of those sessions, and the raw logs are in [`logs/`](logs/).

**Sessions 9–20** need a Kubernetes cluster, a cloud API or a monitoring stack,
so every one of them is a script that a GitHub Actions workflow runs on a fresh
machine, saving the full transcript next to the README:

| Workflow | Runs |
|---|---|
| [`sessions-lab.yml`](.github/workflows/sessions-lab.yml) | sessions 9–15 on a 2-node kind cluster, 18–19 with Terraform, 20 with Docker Compose and Argo CD |
| [`session16-cicd.yml`](.github/workflows/session16-cicd.yml) | session 16's own pipeline |
| [`session17-devsecops.yml`](.github/workflows/session17-devsecops.yml) | session 17's own pipeline |

The lab scripts for sessions 13–20 don't just run commands, they **check the results** (the
PVC is Bound, the HPA scaled past its minimum, the bad Helm upgrade is marked
failed, the bucket is encrypted, Argo CD synced the exact commit that was
pushed, and so on) and ends with a `Verified results: N passed, 0 failed`
summary. If any check fails, the job fails. That caught real problems while
building this: an AWS emulator that never started, a capture script that
stopped halfway through, and a password I had committed (see
[Session 17](16-devsecops/#the-secret-scan-caught-a-real-mistake)).
