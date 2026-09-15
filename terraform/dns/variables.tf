variable "region_default" {
  description = "Regiao AWS onde esta o ALB do Gateway."
  type        = string
  default     = "us-east-1"
}

variable "cloudflare_api_token" {
  description = "API Token do Cloudflare com permissao Zone.DNS:Edit."
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Zone ID do dominio no Cloudflare."
  type        = string
  sensitive   = true
}

# Organizacao HCP onde vive o workspace da infra (para ler os outputs dela).
variable "tfc_organization" {
  description = "Organizacao no HCP Terraform / Terraform Cloud."
  type        = string
  default     = "bgt3"
}

variable "infra_workspace" {
  description = "Workspace HCP da infra, de onde este state le cluster_name e hostnames."
  type        = string
  default     = "wrench_auto_repair"
}
