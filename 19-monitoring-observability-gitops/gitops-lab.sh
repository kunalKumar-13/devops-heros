#!/usr/bin/env bash
# Session 20 lab, part 2: GitOps with Argo CD.
#
# Needs a kind (or any) cluster in the current kubectl context, and a Git
# branch for Argo CD to follow, named in $GITOPS_BRANCH and pushed to origin.
# The script makes a real commit on that branch and pushes it, which is the
# "make a Git change" step: the cluster then follows Git, not kubectl.
set -uo pipefail
cd "$(dirname "$0")"
source ../labs/lib.sh

ARGOCD_VERSION="${ARGOCD_VERSION:-v3.5.4}"
BRANCH="${GITOPS_BRANCH:?set GITOPS_BRANCH to the branch Argo CD should follow}"
NS=session20

wait_replicas() {  # wait until the deployment reports $1 ready replicas
  for i in $(seq 1 60); do
    r=$(kubectl get deploy session20-mini -n $NS -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    [ "${r:-0}" = "$1" ] && return 0
    sleep 3
  done
  return 1
}

banner "1. Install Argo CD $ARGOCD_VERSION"
run kubectl create namespace argocd
runsh "kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml | tail -5"
runsh "kubectl -n argocd rollout status deployment/argocd-server --timeout=300s && kubectl -n argocd rollout status deployment/argocd-repo-server --timeout=300s && kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s"
run kubectl get pods -n argocd

banner "2. The Git side: what Argo CD will watch"
note "repository https://github.com/kunalKumar-13/devops-heros, branch $BRANCH, path 19-monitoring-observability-gitops/gitops/app"
runsh "ls gitops/app && grep -n 'replicas' gitops/app/deployment.yaml"

banner "3. Create the Application"
runsh "sed 's#TARGET_REVISION#$BRANCH#' argocd/application.yaml | kubectl apply -f -"
for i in $(seq 1 60); do
  s=$(kubectl get application session20-mini -n argocd -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null)
  [ "$s" = "Synced/Healthy" ] && break
  sleep 5
done
run kubectl get applications -n argocd
expect_sh "Argo CD reports the app Synced and Healthy" "[ \"\$(kubectl get application session20-mini -n argocd -o jsonpath='{.status.sync.status}/{.status.health.status}')\" = Synced/Healthy ]"

banner "4. What Argo CD created in the cluster"
run kubectl get all -n $NS
expect "Argo CD created the deployment with 2 ready replicas, as Git says" wait_replicas 2

banner "5. Make a Git change: scale from 2 to 3 replicas, in Git only"
runsh "sed -i 's/replicas: 2/replicas: 3/' gitops/app/deployment.yaml && git diff gitops/app/deployment.yaml"
runsh "git add gitops/app/deployment.yaml && git -c user.name=kunalKumar-13 -c user.email=kunalsain0324@gmail.com commit -q -m 'Scale application to three replicas' && git log --oneline -1"
runsh "git push -q origin HEAD:$BRANCH && echo pushed to $BRANCH"
note "no kubectl apply from here on: only Git changed"
run kubectl annotate application session20-mini -n argocd argocd.argoproj.io/refresh=normal --overwrite
wait_replicas 3
run kubectl get deployment session20-mini -n $NS
runsh "kubectl get application session20-mini -n argocd -o jsonpath='synced to commit: {.status.sync.revision}{\"\\n\"}'"
runsh "git rev-parse HEAD"
note "the synced revision is the commit just pushed: Git -> Argo CD -> Kubernetes"
expect "after the Git change the deployment has 3 ready replicas" wait_replicas 3
expect_sh "Argo CD synced exactly the commit that was pushed" "[ \"\$(kubectl get application session20-mini -n argocd -o jsonpath='{.status.sync.revision}')\" = \"\$(git rev-parse HEAD)\" ]"

banner "6. Self-healing: change the cluster by hand and watch Argo CD undo it"
run kubectl scale deployment session20-mini -n $NS --replicas=1
run kubectl get deployment session20-mini -n $NS
note "Git still says 3, and selfHeal is on"
wait_replicas 3
run kubectl get deployment session20-mini -n $NS
runsh "kubectl get events -n $NS --sort-by=.lastTimestamp | grep -i scaled | tail -4"
expect "self-healing: a manual scale to 1 was reverted to 3" wait_replicas 3

banner "7. Pruning: delete the Service by hand, Argo CD recreates it"
run kubectl delete service session20-mini -n $NS
sleep 20
run kubectl get service session20-mini -n $NS
expect "a Service deleted by hand was recreated by Argo CD" kubectl get service session20-mini -n $NS

banner "8. Observe the system"
run kubectl logs deployment/session20-mini -n $NS --tail=5
runsh "kubectl get application session20-mini -n argocd -o jsonpath='{range .status.history[*]}{.id}  {.revision}  {.deployedAt}{\"\\n\"}{end}'"

finish
