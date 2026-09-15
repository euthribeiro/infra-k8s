# Versao minima do Terraform e providers utilizados no projeto.
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    # Helm instala os controllers de cluster (AWS Load Balancer Controller).
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    # tls: usado apenas para obter o thumbprint do emissor OIDC do EKS (IRSA).
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    # kubectl: aplica os CRDs da Gateway API (apply em apply-time, ideal p/ CRDs).
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
    # http: baixa os YAMLs dos CRDs a partir das URLs oficiais.
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}
