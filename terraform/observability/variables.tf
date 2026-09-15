variable "newrelic_account_id" {
  description = "ID da conta New Relic que recebe a telemetria da aplicacao e do cluster."
  type        = number
}

variable "newrelic_api_key" {
  description = "User API key do New Relic (formato NRAK-...), usada pelo provider para criar dashboards, alertas e synthetics."
  type        = string
  sensitive   = true
}

variable "newrelic_region" {
  description = "Regiao da conta New Relic: US ou EU."
  type        = string
  default     = "US"

  validation {
    condition     = contains(["US", "EU"], var.newrelic_region)
    error_message = "newrelic_region deve ser US ou EU."
  }
}

variable "alert_email" {
  description = "E-mail que recebe as notificacoes das condicoes de alerta."
  type        = string
}

variable "service_name" {
  description = "Valor de service.name publicado pela API (Observability:ServiceName)."
  type        = string
  default     = "wrench-auto-repair-api"
}

variable "cluster_name" {
  description = "Nome do cluster EKS informado ao nri-bundle (global.cluster)."
  type        = string
  default     = "eks-wrench-auto-repair"
}

variable "app_health_url" {
  description = "URL publica do liveness da API verificada pelo synthetic monitor."
  type        = string
  default     = "https://api.bgt3.com.br/health"
}

variable "api_pod_prefix" {
  description = "Prefixo do nome dos pods da API no cluster."
  type        = string
  default     = "wrench-api"
}

variable "synthetic_locations" {
  description = "Localizacoes publicas de onde o synthetic monitor executa."
  type        = list(string)
  default     = ["US_EAST_1", "SA_EAST_1"]
}

variable "latencia_p95_limite_ms" {
  description = "Limite de latencia p95 da API, em milissegundos, para abrir incidente."
  type        = number
  default     = 1500
}

variable "taxa_erro_5xx_limite_percentual" {
  description = "Percentual de respostas 5xx da API que abre incidente."
  type        = number
  default     = 5
}
