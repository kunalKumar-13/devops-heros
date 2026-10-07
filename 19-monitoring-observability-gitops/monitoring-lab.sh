#!/usr/bin/env bash
# Session 20 lab, part 1: monitoring with Prometheus and Grafana (Docker Compose).
set -uo pipefail
cd "$(dirname "$0")/monitoring"
source ../../labs/lib.sh

banner "1. Start Prometheus, node exporter, a sample app and Grafana"
run docker compose up -d
for i in $(seq 1 40); do
  curl -fsS localhost:9090/-/ready >/dev/null 2>&1 && curl -fsS localhost:3000/api/health >/dev/null 2>&1 && break
  sleep 3
done
run docker compose ps

banner "2. Metrics: the raw format Prometheus scrapes"
runsh "curl -s localhost:8080/metrics | grep -E '^(# HELP|# TYPE)?.*http_requests_total' | head -6"

banner "3. Generate traffic, including some errors"
runsh "for i in \$(seq 1 300); do curl -s -o /dev/null localhost:8080/; done; for i in \$(seq 1 40); do curl -s -o /dev/null localhost:8080/err; done; echo 'sent 300 good + 40 error requests'"
sleep 20

banner "4. Prometheus: are all scrape targets up?"
runsh "curl -s localhost:9090/api/v1/targets | python3 -c \"import json,sys; [print(t['labels']['job'].ljust(12), t['scrapeUrl'].ljust(36), t['health']) for t in json.load(sys.stdin)['data']['activeTargets']]\""

banner "5. PromQL queries"
q() { curl -s localhost:9090/api/v1/query --data-urlencode "query=$1" | python3 -c "import json,sys; [print(r['metric'], '=>', r['value'][1]) for r in json.load(sys.stdin)['data']['result']]"; }
printf '%s@%s:~$ # sum(up)\n' "$PROMPT_USER" "$PROMPT_HOST"; q 'sum(up)'; echo
printf '%s@%s:~$ # requests per second by status code\n' "$PROMPT_USER" "$PROMPT_HOST"; q 'sum by (code) (rate(http_requests_total{job="sample-app"}[1m]))'; echo
printf '%s@%s:~$ # error ratio\n' "$PROMPT_USER" "$PROMPT_HOST"; q 'sum(rate(http_requests_total{job="sample-app",code!="200"}[1m])) / sum(rate(http_requests_total{job="sample-app"}[1m]))'; echo
printf '%s@%s:~$ # host CPU busy %%\n' "$PROMPT_USER" "$PROMPT_HOST"; q '100 - avg(rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100'; echo

banner "6. Logs: the other signal, for the same app"
run docker compose logs --tail=5 sample-app

banner "7. Grafana: datasource and dashboard, provisioned from files"
runsh "curl -s localhost:3000/api/health"
runsh "curl -s -u admin:kunal-demo localhost:3000/api/datasources | python3 -c \"import json,sys; [print(d['name'], d['type'], d['url']) for d in json.load(sys.stdin)]\""
runsh "curl -s -u admin:kunal-demo 'localhost:3000/api/search?query=Session' | python3 -c \"import json,sys; [print(d['title'], d['url']) for d in json.load(sys.stdin)]\""
