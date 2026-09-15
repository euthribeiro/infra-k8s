variable "projectName" {
  default     = "wrench-auto-repair"
  description = "Nome do projeto de infraestrutura a ser construida com IaC Terraform."
}

variable "region_default" {
  default     = "us-east-1"
  description = "Regiao para alocacao do recursos de infraestrutura."
}

variable "iam_username" {
  default     = "terraform-adm-access"
  description = "Usuário para conceder permissões do EKS"
}

variable "cidr_vpc" {
  default     = "10.0.0.0/16"
  description = "CIDR utilizado pela VPC principal. Por padrao utilizamos o /16 que nos disponibiliza um total de 65.534 IPs utilizaveis."
}

variable "subnet_count" {
  default     = 3
  description = "Quantidade de subnets a serem criadas"
}

variable "main_instance_type" {
  default     = "t3.medium"
  description = "Tipo da instancia dos nodes do EKS"
}

variable "main_tags" {

  type = object({
    Terraform   = string
    Environment = string
  })

  default = {
    Terraform   = "true"
    Environment = "Development"
  }

  validation {
    condition     = contains(["true", "false"], var.main_tags.Terraform)
    error_message = "The 'Terraform' tag must be either 'true' or 'false' as a string."
  }


  validation {
    condition     = contains(["Development", "Staging", "Production"], var.main_tags.Environment)
    error_message = "O ambiente deve ser: Development, Staging ou Production"
  }
}

variable "cloudflare_api_token" {
  description = "API Token do Cloudflare com permissao Zone.DNS:Edit"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Zone ID do dominio no Cloudflare"
  type        = string
  sensitive   = true
}

variable "root_domain" {
  description = "Dominio raiz gerenciado no Cloudflare"
  type        = string
  default     = "bgt3.com.br"
}

# Hostnames cobertos pelo certificado ACM (HTTPS). O AWS Load Balancer
# Controller descobre o certificado pelo HOSTNAME do listener do Gateway, entao
# o(s) nome(s) aqui devem bater com os hostnames usados no Gateway/HTTPRoute do
# Helm. Ex.: ["api.bgt3.com.br"] ou um curinga ["*.bgt3.com.br"].
variable "acm_domains" {
  description = "Dominios/SANs cobertos pelo certificado ACM da aplicacao (HTTPS)."
  type        = list(string)
  default     = ["api.bgt3.com.br"]

  validation {
    condition     = length(var.acm_domains) > 0
    error_message = "Informe ao menos um dominio para o certificado ACM."
  }
}

# Versao do chart Helm do AWS Load Balancer Controller.
# 3.4.0 traz suporte GA a Gateway API (ALB L7 exige controller >= v2.14.0).
variable "lbc_chart_version" {
  description = "Versao do chart Helm do AWS Load Balancer Controller."
  type        = string
  default     = "3.4.0"
}
