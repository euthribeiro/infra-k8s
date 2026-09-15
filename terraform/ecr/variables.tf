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