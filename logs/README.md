# Raw session logs

The unedited output of every session quoted in the task READMEs, exactly as captured
from the terminal on **Ubuntu 26.04** as `kunal@kunal-devops`.

| File | Session |
|---|---|
| `linux1.txt` | soft links and hard links |
| `linux2.txt` | `adduser` vs `useradd` |
| `linux3.txt` | `journalctl` |
| `linux4.txt` | the Linux command cheat sheet, run end to end |
| `shell.txt` | `system_info.sh` running interactively |
| `net.txt` | the networking commands |
| `git1.txt` | `git commit -a -m` vs `git commit -m` |
| `git2.txt` | the cherry-pick exercise |
| `docker_apps.txt` | building and running the six Hello World apps |
| `multistage.txt` | cloning, building and running the multi-stage Dockerfile |
| `netvol_part1.txt` | container networking and the host network |
| `netvol_part2.txt` | bind mount, named volume and the overlay network |

## Kubernetes sections (08-11)

Those sections have no captured logs yet. The tooling to produce them lives here:

| File | What it does |
|---|---|
| `cluster-up.sh` | installs kubectl + kind if missing, creates a 2-node cluster with ports 80/443 mapped, installs the NGINX ingress controller. `./logs/cluster-up.sh down` tears it down |
| `kind-cluster.yaml` | the kind config it uses - the second worker is what gives the DaemonSet in section 09 more than one node to land on |
| `capture-k8s.sh` | runs every command in sections 08-11 and writes `k8s1.txt` .. `k8s4.txt` here. Detects minikube, kind or k3s and adapts the three commands that differ |

```bash
./logs/cluster-up.sh        # skip if minikube is already running
./logs/capture-k8s.sh       # ~15 min, unattended
```

Nothing here is edited. The task READMEs quote these files section by section and add
the explanations.
