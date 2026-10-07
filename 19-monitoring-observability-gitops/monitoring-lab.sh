#!/usr/bin/env bash
# Session 20 lab, part 1: monitoring with Prometheus and Grafana (Docker Compose).
set -uo pipefail
cd "$(dirname "$0")/monitoring"
source ../../labs/lib.sh

# A fresh admin password for every run, kept out of the repository. (An
# earlier version of this script had one written inline; the secret-scanning
# job in Session 17 caught it.)
: "${GRAFANA_ADMIN_PASSWORD:=$(openssl rand -hex 16)}"
export GRAFANA_ADMIN_PASSWORD

banner "1. Start Prometheus, node exporter, a sample app and Grafana"
run docker compose up -d
for i in $(seq 1 40); do
  curl -fsS localhost:9090/-/ready >/dev/null 2>&1 && curl -fsS localhost:3000/api/health >/dev/null 2>&1 && break
  sleep 3
done
run docker compose ps

banner "2. Metrics: the raw format Prometheus scrapes"
runsh "curl -s localhost:8080/metrics | grep -E '^(# HELP|# TYPE)?.*http_requests_total' | head -6"

banner "3. Generate steady traffic, about 10% of it errors"
note "rate() measures the increase BETWEEN scrapes, so a short burst sent before the first scrape reads as 0 req/s. A steady stream that runs for several minutes is what a real service looks like."
# keeps running after this script ends, so the dashboard screenshot shows live traffic
nohup setsid bash -c 'end=$((SECONDS + 420)); while [ $SECONDS -lt $end ]; do
  for i in 1 2 3 4 5 6 7 8 9; do curl -s -o /dev/null localhost:8080/; done
  curl -s -o /dev/null localhost:8080/err
  sleep 0.5
done' >/dev/null 2>&1 &
note "traffic generator started (pid $!); letting Prometheus collect a minute of samples"
sleep 70

banner "4. Prometheus: are all scrape targets up?"
runsh "curl -s localhost:9090/api/v1/targets | python3 -c \"import json,sys; [print(t['labels']['job'].ljust(12), t['scrapeUrl'].ljust(36), t['health']) for t in json.load(sys.stdin)['data']['activeTargets']]\""

banner "5. PromQL queries"
q() { curl -s localhost:9090/api/v1/query --data-urlencode "query=$1" | python3 -c "import json,sys; [print(r['metric'], '=>', r['value'][1]) for r in json.load(sys.stdin)['data']['result']]"; }
printf '%s@%s:~$ # sum(up)\n' "$PROMPT_USER" "$PROMPT_HOST"; q 'sum(up)'; echo
printf '%s@%s:~$ # requests per second by status code\n' "$PROMPT_USER" "$PROMPT_HOST"; q 'sum by (code) (rate(http_requests_total{job="sample-app"}[1m]))'; echo
printf '%s@%s:~$ # error ratio\n' "$PROMPT_USER" "$PROMPT_HOST"; q 'sum(rate(http_requests_total{job="sample-app",code!="200"}[1m])) / sum(rate(http_requests_total{job="sample-app"}[1m]))'; echo
printf '%s@%s:~$ # host CPU busy %%\n' "$PROMPT_USER" "$PROMPT_HOST"; q '100 - avg(rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100'; echo

qv() { curl -s localhost:9090/api/v1/query --data-urlencode "query=$1" | python3 -c "import json,sys; r=json.load(sys.stdin)['data']['result']; print(r[0]['value'][1] if r else 'nan')"; }
expect_sh "all 3 scrape targets are up" "[ \"\$(curl -s localhost:9090/api/v1/query --data-urlencode 'query=sum(up)' | python3 -c \"import json,sys; print(json.load(sys.stdin)['data']['result'][0]['value'][1])\")\" = 3 ]"
RATE=$(qv 'sum(rate(http_requests_total{job="sample-app"}[1m]))')
ERR=$(qv 'sum(rate(http_requests_total{job="sample-app",code!="200"}[1m])) / sum(rate(http_requests_total{job="sample-app"}[1m]))')
expect "Prometheus measures live traffic (rate = $RATE req/s)" python3 -c "import sys; sys.exit(0 if float('$RATE') > 0 else 1)"
expect "the error ratio is measured and plausible (about 10%: $ERR)" python3 -c "import sys; e=float('$ERR'); sys.exit(0 if 0.03 < e < 0.25 else 1)"

banner "6. Logs: the other signal, for the same app"
run docker compose logs --tail=5 sample-app

banner "7. Grafana: datasource and dashboard, provisioned from files"
runsh "curl -s localhost:3000/api/health"
runsh "curl -s -u \"admin:\$GRAFANA_ADMIN_PASSWORD\" localhost:3000/api/datasources | python3 -c \"import json,sys; [print(d['name'], d['type'], d['url']) for d in json.load(sys.stdin)]\""
runsh "curl -s -u \"admin:\$GRAFANA_ADMIN_PASSWORD\" 'localhost:3000/api/search?query=Session' | python3 -c \"import json,sys; [print(d['title'], d['url']) for d in json.load(sys.stdin)]\""

expect_sh "Grafana is healthy" "curl -sf localhost:3000/api/health | grep -q ok"
expect_sh "the Prometheus datasource was provisioned" "curl -sf -u \"admin:\$GRAFANA_ADMIN_PASSWORD\" localhost:3000/api/datasources | grep -q prometheus"
expect_sh "the Session 20 dashboard was provisioned" "curl -sf -u \"admin:\$GRAFANA_ADMIN_PASSWORD\" 'localhost:3000/api/search?query=Session' | grep -q session20"

finish
