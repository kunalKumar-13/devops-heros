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

# ---------------------------------------------------------------------------
# Assertions. Labs deliberately run commands that fail (that is the point of a
# troubleshooting lab), so a failing command alone cannot fail the lab. Instead
# each lab states what must be true, and `finish` fails the run if any of it
# is not. The summary at the end of every transcript is the verified result.
# ---------------------------------------------------------------------------
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECK_LOG=""

# expect "<what must be true>" <command...>   (silent; records pass/fail)
expect() {
  local what="$1"; shift
  if "$@" >/dev/null 2>&1; then
    CHECKS_PASSED=$((CHECKS_PASSED + 1)); CHECK_LOG+="  PASS  $what"$'\n'
  else
    CHECKS_FAILED=$((CHECKS_FAILED + 1)); CHECK_LOG+="  FAIL  $what"$'\n'
  fi
}

# expect_sh "<what must be true>" "<shell condition>"
expect_sh() {
  expect "$1" bash -c "$2"
}

finish() {
  banner "Verified results: $CHECKS_PASSED passed, $CHECKS_FAILED failed"
  printf '%s\n' "$CHECK_LOG"
  [ "$CHECKS_FAILED" -eq 0 ]
}
