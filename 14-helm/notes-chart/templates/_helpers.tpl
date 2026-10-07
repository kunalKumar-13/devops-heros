{{/* Labels shared by every object in the release. */}}
{{- define "notes.labels" -}}
app: {{ .Release.Name }}
environment: {{ .Values.app.environment }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
