{{/*
Common labels for all resources
*/}}
{{- define "nginx-app.labels" -}}
app: nginx-app
chart: {{ .Chart.Name }}-{{ .Chart.Version }}
release: {{ .Release.Name }}
managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels (used for matchLabels and service selectors)
*/}}
{{- define "nginx-app.selectorLabels" -}}
app: nginx-app
release: {{ .Release.Name }}
{{- end }}

{{/*
Common annotations for monitoring and logging
*/}}
{{- define "nginx-app.annotations" -}}
prometheus.io/scrape: "true"
prometheus.io/port: "80"
logging/enabled: "true"
{{- end }}
