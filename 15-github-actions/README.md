# Session 16 — CI/CD with GitHub Actions

**Kunal Kumar · Roll No. 24BCS10027**

The session's final pipeline, built for a small Python calculator: test on
every push, build only after the tests pass, a basic security check, an
uploaded build artifact, and a release step that uses a repository secret.
Then the failure scenario from the session, done for real: a broken commit
that turns the pipeline red and stops the build, and the fix that turns it
green again.

- Workflow: [`.github/workflows/session16-cicd.yml`](../.github/workflows/session16-cicd.yml)
- Runs: [Actions → "Session 16: CI/CD"](https://github.com/kunalKumar-13/devops-heros/actions/workflows/session16-cicd.yml)
- Output of the runs used below: [`session-output.txt`](session-output.txt)

---

## Files

| File | What it is |
|---|---|
| [`app/calculator.py`](app/calculator.py) | `add`, `subtract`, `multiply`, `divide` (refuses zero), `percentage` |
| [`tests/test_calculator.py`](tests/test_calculator.py) | 6 pytest tests |
| [`requirements.txt`](requirements.txt) | pinned `pytest` and `pytest-cov` |
| [`build.sh`](build.sh) | packages the app into `dist/calculator-<commit>.tar.gz` plus `dist/build-info.txt` |

Run it locally:

```bash
python -m pip install -r requirements.txt
python app/calculator.py      # prints a few results
pytest -v
bash build.sh
```

## The pipeline

```text
push / pull request / manual / every Monday 03:00 UTC
        │
        ▼
 test  (matrix: ubuntu + windows × Python 3.11, 3.12, 3.13 = 6 jobs)
        │  needs: test
        ├──────────────────────┐
        ▼                      ▼
 build                     security-check
 (dist/ → artifact          (no .env / .pem / .key files,
  "calculator-build")        no hard-coded credentials in app/)
        │                      │
        └──────────┬───────────┘
                   ▼  needs: [build, security-check]
               release   (only on push or manual run, never on a PR)
               downloads the artifact, reads secrets.RELEASE_NOTE
```

What each piece from the session looks like here:

| Concept | Where |
|---|---|
| **Triggers** | `push` to `assignment` (only when this folder or the workflow changes), `pull_request`, `workflow_dispatch`, and a `schedule` cron that catches dependency drift |
| **Jobs and steps** | four jobs; each step is either an action (`uses:`) or a shell command (`run:`) |
| **Sequential vs parallel** | `needs: test` makes build wait for every test job; build and security-check then run side by side |
| **Matrix** | one job definition, six runs (2 OS × 3 Python versions), `fail-fast: false` so one failure doesn't hide the others |
| **Runners** | GitHub-hosted `ubuntu-latest` and `windows-latest`; the first step prints which runner it got |
| **Artifacts** | build uploads `dist/` as `calculator-build` (kept 14 days); release downloads it in a different job, on a different machine |
| **Secrets** | `RELEASE_NOTE` is set in the repository settings (`gh secret set RELEASE_NOTE`), passed to the step as an env var, and masked as `***` in the logs |
| **Conditional job** | `release` has `if: github.event_name == 'push' \|\| ...`, so PRs and scheduled runs test and build but never release |
| **Least privilege** | `permissions: contents: read` at the top; nothing in this workflow can write to the repository |

## The failure scenario

Following the session's steps exactly, on the real repository:

1. **Break it.** Commit `812da7b` changed `add` to `return a + b + 1` and pushed.
   pytest fails with `assert 6 == 5`, on all six matrix jobs.
   **Build, Security check and Release were skipped.** Because of
   `needs: test`, nothing broken can be packaged.
2. **Fix it.** Commit `34a5263` "Fix application" restored `return a + b`.
   Every job went green again and the artifact was uploaded.

There was also an unplanned failure first, which was more useful than the
planned one: the very first run's build job failed with `./build.sh:
Permission denied`. The script had been committed from Windows without the
executable bit. Fixed by recording the mode in git (`git update-index
--chmod=+x`) and calling it as `bash build.sh`.

---

## What happened when it ran

The full output of both runs is in [`session-output.txt`](session-output.txt).

**Run 1, the broken commit** ([run 37655965208](https://github.com/kunalKumar-13/devops-heros/actions/runs/37655965208), commit `812da7b`):

```text
  failure   Test (ubuntu-latest, Python 3.11/3.12/3.13)
  failure   Test (windows-latest, Python 3.11/3.12/3.13)
  skipped   Build            (needs: test)
  skipped   Security check   (needs: test)
  skipped   Release          (needs: [build, security-check])
```

```console
tests/test_calculator.py::test_add FAILED                                [ 16%]
...
    def test_add():
>       assert add(2, 3) == 5
E       assert 6 == 5
E        +  where 6 = add(2, 3)
=========================== short test summary info ============================
FAILED tests/test_calculator.py::test_add - assert 6 == 5
========================= 1 failed, 5 passed in 0.05s ==========================
ERROR: Process completed with exit code 1.
```

**Run 2, "Fix application"** ([run 37656285098](https://github.com/kunalKumar-13/devops-heros/actions/runs/37656285098), commit `34a5263`): all nine jobs green.

```console
runner os   : Windows (X64)
Python 3.12.10
...
============================== 6 passed in 0.16s ==============================

$ bash build.sh
built dist/calculator-34a5263.tar.gz
name: calculator
version: 34a5263
built_by: kunalKumar-13
runner: Linux
Artifact calculator-build has been successfully uploaded! Final size is 952 bytes.

$ ls -l dist          # in the release job, after downloading the artifact
-rw-r--r-- 1 runner runner 103 Oct  7 17:06 build-info.txt
-rw-r--r-- 1 runner runner 566 Oct  7 17:06 calculator-34a5263.tar.gz

the secret is available to this step (63 characters)
printing it directly is masked by GitHub: ***
```

