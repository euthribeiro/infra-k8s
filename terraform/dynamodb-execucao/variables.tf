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

variable "execucao_tabela" {
  description = "Nome da tabela principal de execucoes (aplicacao: Dynamo__Execucao)."
  type        = string
  default     = "wrench-execucao"
}

variable "execucao_outbox_tabela" {
  description = "Nome da tabela do outbox transacional (aplicacao: Dynamo__Outbox)."
  type        = string
  default     = "wrench-execucao-outbox"
}

variable "execucao_idempotencia_tabela" {
  description = "Nome da tabela de idempotencia das mensagens consumidas (aplicacao: Dynamo__Idempotencia)."
  type        = string
  default     = "wrench-execucao-idempotencia"
}
