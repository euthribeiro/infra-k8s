variable "region_default" {
  description = "Regiao AWS onde o SES e verificado (a app deve usar a mesma)."
  type        = string
  default     = "us-east-1"
}

# --- Cloudflare ---
variable "cloudflare_api_token" {
  description = "API Token do Cloudflare com permissao Zone.DNS:Edit."
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Zone ID do dominio no Cloudflare (dashboard > Overview do dominio)."
  type        = string
  sensitive   = true
}

# --- SES ---
variable "domain_name" {
  description = "Dominio de envio verificado no SES (bgt3.com.br)."
  type        = string
  default     = "bgt3.com.br"
}

variable "configuration_set_name" {
  description = "Nome do SES configuration set."
  type        = string
  default     = "wrench-email"
}

variable "reputation_metrics_enabled" {
  description = "Publica metricas de reputacao no CloudWatch."
  type        = bool
  default     = false
}

variable "sending_enabled" {
  description = "Habilita o envio para este configuration set."
  type        = bool
  default     = true
}

variable "custom_redirect_domain" {
  description = "Subdominio para tracking de open/click. Para desabilitar deixe essa var vazia."
  type        = string
  default     = ""
}

# --- Credenciais da aplicacao ---
variable "create_smtp_user" {
  description = "Cria IAM user + access key para a app enviar via SES. false um dia for usar IRSA."
  type        = bool
  default     = false
}

variable "allowed_emails" {
  type = set(string)
  default = [
    "thiago.r.ribeiro16@gmail.com",
    "thiago_santos14@hotmail.com",
    "brunocbarreto2012@gmail.com"
  ]
}

# --- IRSA (recomendado no EKS: sem chaves estaticas) ---
variable "create_irsa_role" {
  description = "Cria a role IRSA que a ServiceAccount da app assume para enviar via SES."
  type        = bool
  default     = true
}

variable "k8s_namespace" {
  description = "Namespace do pod da aplicacao (deve casar com o chart Helm)."
  type        = string
  default     = "production"
}

variable "k8s_service_account" {
  description = "Nome da ServiceAccount da aplicacao anotada com a role IRSA."
  type        = string
  default     = "wrench-api-sa"
}

variable "tfc_organization" {
  description = "Organizacao no HCP Terraform (para ler o remote state da infra)."
  type        = string
  default     = "bgt3"
}

variable "infra_workspace" {
  description = "Workspace do HCP Terraform com o state da infra (OIDC provider)."
  type        = string
  default     = "wrench_auto_repair"
}
