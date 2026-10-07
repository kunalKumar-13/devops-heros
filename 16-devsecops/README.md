# Session 17 — DevSecOps

**Kunal Kumar · Roll No. 24BCS10027**

A complete CI/CD pipeline with security built into it, for a small Flask API.
Code is tested, scanned three different ways (SAST, SCA, secrets), built into
an image, the image is scanned and has to pass a security gate, and only then
is it pushed to GitHub Container Registry and deployed to Kubernetes.

- Workflow: [`.github/workflows/session17-devsecops.yml`](../.github/workflows/session17-devsecops.yml)
- Runs: [Actions → "Session 17: DevSecOps"](https://github.com/kunalKumar-13/devops-heros/actions/workflows/session17-devsecops.yml)
- Image: [`ghcr.io/kunalkumar-13/secure-api`](https://github.com/kunalKumar-13/devops-heros/pkgs/container/secure-api), tagged with the commit
- Output of the runs used below: [`session-output.txt`](session-output.txt)

---

## Files

| File | What it is |
|---|---|
| [`app/main.py`](app/main.py) | Flask API: `GET /health`, `GET /greet?name=`, `GET /add?a=&b=` |
| [`tests/test_app.py`](tests/test_app.py) | 5 pytest tests, including bad input to `/add` |
| [`requirements.txt`](requirements.txt) | runtime deps, pinned: `flask==3.1.3`, `gunicorn==26.2.0` |
| [`requirements-dev.txt`](requirements-dev.txt) | test and scan tools, pinned |
| [`Dockerfile`](Dockerfile) | `python:3.12-slim`, OS packages upgraded, runs as uid 10001, gunicorn |
| [`k8s/deployment.yaml`](k8s/deployment.yaml) | 2 replicas, non-root, read-only root filesystem, all capabilities dropped, probes, limits, plus a Service |

Run it locally:

```bash
pip install -r requirements-dev.txt -r requirements.txt
pytest
python -m app.main                    # http://localhost:8080/health
docker build -t secure-api .
docker run --rm -p 8080:8080 secure-api
```

## The pipeline

```text
            tests (pytest)
                 │
   ┌─────────────┼──────────────────┐
   ▼             ▼                  ▼
 SAST          SCA               secret scan
 CodeQL +      pip-audit         gitleaks, every commit
 Bandit        --strict          in the history
   └─────────────┼──────────────────┘
                 ▼   all three must pass
   build image → Trivy report → Trivy GATE (fixable HIGH/CRITICAL = fail)
                 ▼
   push to GHCR  (the exact image that was scanned; skipped on PRs)
                 ▼
   deploy to Kubernetes (kind) → smoke test → check it runs as non-root
                                              on a read-only filesystem
```

| Stage | Tool | What it catches | Fails the pipeline when |
|---|---|---|---|
| Unit tests | pytest | broken behaviour | any test fails |
| **SAST** | CodeQL, Bandit | insecure code patterns: injection, unsafe deserialisation, debug mode, binding to all interfaces | Bandit finds medium/high severity; CodeQL results go to the Security tab |
| **SCA** | pip-audit | dependencies with published CVEs | any known vulnerability (`--strict`) |
| **Secrets** | gitleaks | passwords, tokens, keys committed anywhere in history | any finding |
| **Image scan** | Trivy | CVEs in the OS packages and Python packages inside the image | a HIGH or CRITICAL with a fix available |
| **Registry** | GHCR | | push only happens after every gate above |
| **Deploy** | kind + kubectl | | rollout fails, smoke test fails |

Some decisions worth explaining:

- **Push after scan, not before.** The image is built once, scanned, saved as an
  artifact, and *that file* is loaded and pushed. Nothing unscanned can reach
  the registry, and the deploy uses the same image again.
- **Two Trivy steps.** The first prints everything and never fails, so the full
  picture is in the log. The second is the gate: only `HIGH,CRITICAL` with
  `ignore-unfixed: true`. Failing on CVEs nobody can fix yet would just train
  people to ignore the gate.
- **Least privilege.** The workflow starts with `contents: read`. Only the SAST
  job gets `security-events: write` and only the push job gets
  `packages: write`. The registry login uses the built-in `GITHUB_TOKEN`, no
  stored password.
- **Pinned actions.** Third-party actions (Trivy, docker/login, kind, CodeQL)
  are pinned to a full commit SHA. A tag can be moved to different code if
  someone compromises the action's repository; a SHA cannot.
- **Hardened at runtime too.** Non-root user in the Dockerfile *and*
  `runAsNonRoot` in Kubernetes, read-only root filesystem with an `emptyDir`
  for `/tmp`, `allowPrivilegeEscalation: false`, all Linux capabilities dropped.

## The secret scan caught a real mistake

The first time this pipeline ran, **the secret-scanning job failed**:

```text
RuleID:      curl-auth-user
File:        19-monitoring-observability-gitops/monitoring-lab.sh
Line:        36
Commit:      df0935713336bbfca581d76683f6f4a7433b57b2
WRN leaks found: 1
```

I had written the Grafana admin password for the Session 20 demo directly into
a `curl -u admin:<password>` line in that lab script (and into the compose
file). Everything after the scan (build, push, deploy) was skipped, which is
the point of the gate.

How it was fixed (commit `a3081c8`):

1. The lab generates a random password for every run (`openssl rand -hex 16`)
   and passes it through an environment variable. In CI it is also masked
   with `::add-mask::`.
2. The compose file refuses to start without it:
   `${GRAFANA_ADMIN_PASSWORD:?set GRAFANA_ADMIN_PASSWORD}`.
3. The old commit is still in history. Rewriting a pushed branch is worse than
   the problem here (the password only ever protected a throwaway container on
   a CI runner), so the finding's fingerprint is listed in
   [`.gitleaksignore`](../.gitleaksignore) with the reason, instead of being
   silently allowlisted. Anyone reading the repo can see what happened.

The next run: `55 commits scanned ... no leaks found`, and the pipeline went
all the way to deploy.

---

## What happened when it ran

The full output of both runs is in [`session-output.txt`](session-output.txt).

**Run 1** ([run 37651413890](https://github.com/kunalKumar-13/devops-heros/actions/runs/37651413890)): tests, SAST and SCA passed, the secret scan failed, and nothing was built, pushed or deployed.

**Run 2** ([run 37656475701](https://github.com/kunalKumar-13/devops-heros/actions/runs/37656475701), commit `b202ae8`): every job green.

```console
$ pytest
============================== 5 passed in 0.12s ===============================

$ bandit -r app -ll -f txt
Test results:
	No issues identified.
Code scanned:
	Total lines of code: 24

$ pip-audit -r requirements.txt --strict --desc
No known vulnerabilities found

$ ./gitleaks git --redact --verbose --exit-code 1 .
5:06PM INF 61 commits scanned.
5:06PM INF no leaks found

$ trivy image ...      # report: everything, never fails
ghcr.io/kunalkumar-13/secure-api:b202ae83e8a4 (debian 13.7)
Total: 165 (UNKNOWN: 2, LOW: 61, MEDIUM: 58, HIGH: 44, CRITICAL: 0)
Python (python-pkg)
Total: 6 (UNKNOWN: 0, LOW: 1, MEDIUM: 5, HIGH: 0, CRITICAL: 0)

$ trivy image ...      # gate: HIGH,CRITICAL, ignore-unfixed, exit-code 1
│ ghcr.io/kunalkumar-13/secure-api:b202ae83e8a4 (debian 13.7) │ debian │ 0 │
│ (every Python package)                                       │ python-pkg │ 0 │

$ docker push ghcr.io/kunalkumar-13/secure-api:b202ae83e8a4
b202ae83e8a4: digest: sha256:65f92438725ef12f7c2a2adb7ec91adf464e46967302aa1340df599543468a59 size: 2405

$ kubectl rollout status deployment/secure-api
deployment "secure-api" successfully rolled out
secure-api-5879dcd7f8-4n2q4   1/1     Running   0          6s
secure-api-5879dcd7f8-sl5zh   1/1     Running   0          6s

$ kubectl logs smoke
{"status":"ok","version":"b202ae83e8a4"}
{"result":5.0}
user inside the container: uid=10001(appuser) gid=10001(appuser) groups=10001(appuser)
touch: cannot touch '/app/x': Read-only file system
```

Reading the Trivy numbers: the base image has 44 HIGH findings in Debian
packages, and **none of them has a fix released yet** (the image already runs
`apt-get upgrade`, which upgraded nothing because there was nothing to
upgrade to). That's why the gate passes. The day Debian ships a fix, the gate
starts failing until the image is rebuilt. The 6 findings in the Python
packages are all in `pip` itself, LOW/MEDIUM, and pip isn't used at runtime.

