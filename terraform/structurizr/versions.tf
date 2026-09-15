terraform {
  required_version = ">= 1.5.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    # Gera o secret do tunnel (usado para montar o token do conector).
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
