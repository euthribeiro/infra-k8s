# Configuracao dos providers.
# AWS: regiao padrao vinda das variaveis.
provider "aws" {
  region = var.region_default
}

# Cloudflare: autenticacao por API token (permissao Zone.DNS:Edit).
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}