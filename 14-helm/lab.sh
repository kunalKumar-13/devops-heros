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

banner "1. Chart structure"
runsh "find notes-chart -type f | sort"
run cat notes-chart/Chart.yaml

banner "2. Lint"
run helm lint notes-chart
run helm lint notes-chart -f notes-chart/values-prod.yaml

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

banner "5. Upgrade to production values"
run helm upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml --wait --timeout 3m
run kubectl get pods -l app=notes-dev
printf '%s@%s:~$ curl -s http://notes-dev-svc\n' "$PROMPT_USER" "$PROMPT_HOST"; page 2; echo

banner "6. Release history"
run helm history notes-dev

banner "7. A bad upgrade: an image tag that does not exist"
note "--wait makes Helm wait for the rollout, so a broken image fails the release instead of quietly succeeding"
run helm upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml --set image.tag=9.99-doesnotexist --wait --timeout 60s
run helm history notes-dev
run kubectl get pods -l app=notes-dev
note "the old ReplicaSet's pods are still serving: a failed rolling update never removes working pods before new ones are ready"

banner "8. Roll back to revision 2"
run helm rollback notes-dev 2 --wait --timeout 3m
run helm history notes-dev
runsh "kubectl rollout status deployment/notes-dev-deploy --timeout=180s"
run kubectl get pods -l app=notes-dev
printf '%s@%s:~$ curl -s http://notes-dev-svc\n' "$PROMPT_USER" "$PROMPT_HOST"; page 3; echo

banner "9. What Helm stored about the release"
run helm list
runsh "helm get values notes-dev --revision 2"

banner "10. Clean up"
run helm uninstall notes-dev
run kubectl get all -l app=notes-dev
