variable "cloudflare_api_token" {
  description = "API token Cloudflare com permissao de conta para Tunnel (e Zone.DNS:Edit)."
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Account ID da Cloudflare (Dashboard > Overview do dominio, coluna direita)."
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Zone ID do dominio no Cloudflare."
  type        = string
  sensitive   = true
}

variable "tunnel_name" {
  description = "Nome do Cloudflare Tunnel."
  type        = string
  default     = "structurizr-wrench"
}

variable "hostname" {
  description = "Hostname publico do Structurizr."
  type        = string
  default     = "structurizr-wrench-api.bgt3.com.br"
}

variable "subdomain" {
  description = "Subdominio (parte antes do dominio raiz) para o registro DNS."
  type        = string
  default     = "structurizr-wrench-api"
}

# Servico interno para onde o tunnel encaminha (Service ClusterIP do chart Helm).
variable "internal_service" {
  description = "URL do Service do Structurizr Lite dentro do cluster."
  type        = string
  default     = "http://structurizr-lite.structurizr.svc.cluster.local:8080"
}
