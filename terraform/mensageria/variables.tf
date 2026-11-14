variable "region_default" {
  default     = "us-east-1"
  description = "Regiao para alocacao do recursos de infraestrutura."
}

variable "main_tags" {

  type = object({
    Terraform   = string
    Environment = string
  })

  default = {
    Terraform   = "true"
    Environment = "development"
  }

  validation {
    condition     = contains(["true", "false"], var.main_tags.Terraform)
    error_message = "The 'Terraform' tag must be either 'true' or 'false' as a string."
  }

  validation {
    condition     = contains(["development", "staging", "production"], var.main_tags.Environment)
    error_message = "O ambiente deve ser: development, staging ou production"
  }
}

variable "tfc_organization" {
  description = "Organizacao do Terraform Cloud que hospeda os workspaces."
  type        = string
  default     = "bgt3"
}

variable "infra_workspace" {
  description = "Workspace do stack infra/, de onde vem o OIDC provider do cluster EKS."
  type        = string
  default     = "wrench_auto_repair_infra"
}

variable "prefixo" {
  description = "Prefixo dos topicos, filas e roles da mensageria."
  type        = string
  default     = "wrench"
}

variable "k8s_namespaces" {
  description = "Namespaces do cluster cujas ServiceAccounts podem assumir as roles IRSA."
  type        = list(string)
  default     = ["production", "homologacao"]
}

variable "max_receive_count" {
  description = "Tentativas de entrega antes de a mensagem ir para a DLQ."
  type        = number
  default     = 5
}

variable "visibility_timeout_seconds" {
  description = "Tempo em que a mensagem fica invisivel apos ser recebida por um consumidor."
  type        = number
  default     = 60
}

variable "message_retention_seconds" {
  description = "Retencao das mensagens na fila principal (4 dias)."
  type        = number
  default     = 345600
}

variable "dlq_message_retention_seconds" {
  description = "Retencao das mensagens na DLQ (14 dias, o maximo do SQS)."
  type        = number
  default     = 1209600
}

variable "dynamodb_table_prefix" {
  description = "Prefixo das tabelas DynamoDB do execucao-service liberadas na role IRSA."
  type        = string
  default     = "wrench-execucao"
}

variable "ses_send_allowed" {
  description = "Inclui ses:SendEmail na role do OS Service, que envia e-mail de acompanhamento da OS pela mesma ServiceAccount."
  type        = bool
  default     = true
}
