{{- define "istio-mesh-chart.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
sidecar.istio.io/inject: "true"
{{- end }}

{{- define "istio-mesh-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
sidecar.istio.io/inject: "true"
{{- end }}

{{- define "istio-mesh-chart.fullname" -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- end }}