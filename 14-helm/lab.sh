#!/usr/bin/env bash
# Session 15 lab: package the notes app with Helm, then lint, render, install,
# upgrade to production values, break an upgrade on purpose and roll back.
set -uo pipefail
cd "$(dirname "$0")"
source ../labs/lib.sh

page() {  # print the rendered page's status line from inside the cluster
  kubectl run "page-$1" --rm -i --restart=Never --image=curlimages/curl:8.10.1 -- \
    curl -s http://notes-dev-svc 2>/dev/null | tr '\n' ' ' | grep -o 'environment:.*image: <b>[^<]*' \
    | sed -e 's/<[^>]*>//g' -e 's/&middot;/|/g' -e 's/  */ /g'
}

rev_status() { helm history notes-dev -o json | python3 -c "import json,sys; h={r['revision']:r['status'] for r in json.load(sys.stdin)}; sys.exit(0 if h.get($1)=='$2' else 1)"; }
ready_is()   { [ "$(kubectl get deploy notes-dev-deploy -o jsonpath='{.status.readyReplicas}')" = "$1" ]; }
image_is()   { kubectl get deploy notes-dev-deploy -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -qx "$1"; }
page_has()   { page "chk$RANDOM" | grep -q "$1"; }
dev_ok()     { ready_is 1 && image_is nginx:1.26-alpine && page_has development; }
prod_ok()    { ready_is 3 && image_is nginx:1.27-alpine && page_has production; }
back_ok()    { ready_is 3 && image_is nginx:1.27-alpine; }
gone()       { [ -z "$(kubectl get all -l app=notes-dev -o name 2>/dev/null)" ]; }

banner "1. Chart structure"
runsh "find notes-chart -type f | sort"
run cat notes-chart/Chart.yaml

banner "2. Lint"
run helm lint notes-chart
run helm lint notes-chart -f notes-chart/values-prod.yaml
expect "the chart lints cleanly with dev and prod values" bash -c "helm lint notes-chart >/dev/null && helm lint notes-chart -f notes-chart/values-prod.yaml >/dev/null"

banner "3. Render locally without installing"
runsh "helm template notes-dev notes-chart | grep -E '^kind|replicas:|image:'"
runsh "helm template notes-dev notes-chart -f notes-chart/values-prod.yaml | grep -E '^kind|replicas:|image:'"

banner "4. Install (development values)"
run helm install notes-dev notes-chart --wait --timeout 3m
run kubectl get pods -l app=notes-dev
run kubectl get services notes-dev-svc
run kubectl get configmaps notes-dev-config
note "the page the app is serving now:"
printf '%s@%s:~$ curl -s http://notes-dev-svc\n' "$PROMPT_USER" "$PROMPT_HOST"; page 1; echo
expect "install: revision 1 deployed" rev_status 1 deployed
expect "install: 1 replica of nginx:1.26-alpine, page says development" dev_ok

banner "5. Upgrade to production values"
run helm upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml --wait --timeout 3m
run kubectl get pods -l app=notes-dev
printf '%s@%s:~$ curl -s http://notes-dev-svc\n' "$PROMPT_USER" "$PROMPT_HOST"; page 2; echo
expect "upgrade: revision 2 deployed" rev_status 2 deployed
expect "upgrade: 3 replicas of nginx:1.27-alpine, page says production" prod_ok

banner "6. Release history"
run helm history notes-dev

banner "7. A bad upgrade: an image tag that does not exist"
note "--wait makes Helm wait for the rollout, so a broken image fails the release instead of quietly succeeding"
run helm upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml --set image.tag=9.99-doesnotexist --wait --timeout 60s
run helm history notes-dev
run kubectl get pods -l app=notes-dev
note "the old ReplicaSet's pods are still serving: a failed rolling update never removes working pods before new ones are ready"
expect "bad upgrade: revision 3 is marked failed" rev_status 3 failed

banner "8. Roll back to revision 2"
run helm rollback notes-dev 2 --wait --timeout 3m
run helm history notes-dev
runsh "kubectl rollout status deployment/notes-dev-deploy --timeout=180s"
run kubectl get pods -l app=notes-dev
printf '%s@%s:~$ curl -s http://notes-dev-svc\n' "$PROMPT_USER" "$PROMPT_HOST"; page 3; echo
expect "rollback: revision 4 deployed" rev_status 4 deployed
expect "rollback: back on nginx:1.27-alpine with 3 ready replicas" back_ok

banner "9. What Helm stored about the release"
run helm list
runsh "helm get values notes-dev --revision 2"

banner "10. Clean up"
run helm uninstall notes-dev
kubectl wait --for=delete pod -l app=notes-dev --timeout=90s >/dev/null 2>&1
run kubectl get all -l app=notes-dev

expect "uninstall: nothing labelled app=notes-dev is left" gone

finish
