# Shared helpers for the session lab scripts. Source it, don't run it.
#
# Every lab prints each command with a shell prompt before its output, so the
# transcript the pipeline saves reads exactly like the terminal session did.

PROMPT_USER="${PROMPT_USER:-kunal}"
PROMPT_HOST="${PROMPT_HOST:-devops-lab}"

banner() {
  printf '\n############################################################\n'
  printf '#  %s\n' "$1"
  printf '############################################################\n\n'
}

# run a single command, echoed first
run() {
  printf '%s@%s:~$ %s\n' "$PROMPT_USER" "$PROMPT_HOST" "$*"
  "$@" 2>&1
  local rc=$?
  printf '\n'
  return $rc
}

# run a shell one-liner (pipes, redirects), echoed first
runsh() {
  printf '%s@%s:~$ %s\n' "$PROMPT_USER" "$PROMPT_HOST" "$1"
  bash -c "$1" 2>&1
  local rc=$?
  printf '\n'
  return $rc
}

# a note in the transcript, for the reader
note() {
  printf '>>> %s\n\n' "$*"
}
