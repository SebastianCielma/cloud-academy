{{- define "payment-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "payment-platform.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "payment-platform.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "payment-platform.labels" -}}
helm.sh/chart: {{ include "payment-platform.chart" . }}
{{ include "payment-platform.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "payment-platform.selectorLabels" -}}
app.kubernetes.io/name: {{ include "payment-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "payment-platform.apiLabels" -}}
{{ include "payment-platform.labels" . }}
app.kubernetes.io/component: api
{{- end }}

{{- define "payment-platform.apiSelectorLabels" -}}
{{ include "payment-platform.selectorLabels" . }}
app.kubernetes.io/component: api
{{- end }}

{{- define "payment-platform.workerLabels" -}}
{{ include "payment-platform.labels" . }}
app.kubernetes.io/component: worker
{{- end }}

{{- define "payment-platform.workerSelectorLabels" -}}
{{ include "payment-platform.selectorLabels" . }}
app.kubernetes.io/component: worker
{{- end }}

{{- define "payment-platform.configmapName" -}}
{{ include "payment-platform.fullname" . }}-config
{{- end }}

{{- define "payment-platform.secretProviderClassName" -}}
{{ include "payment-platform.fullname" . }}-keyvault
{{- end }}
