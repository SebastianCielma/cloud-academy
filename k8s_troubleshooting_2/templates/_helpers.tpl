{{- define "k8s-troubleshooting-ae.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "k8s-troubleshooting-ae.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "k8s-troubleshooting-ae.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
