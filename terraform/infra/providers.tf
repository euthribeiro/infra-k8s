# Configuracao dos providers.
# AWS: regiao padrao vinda das variaveis.
provider "aws" {
  region = var.region_default
}

# Cloudflare: autenticacao por API token (permissao Zone.DNS:Edit).
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Helm autenticado no cluster EKS. Usado apenas para instalar os controllers
# de cluster (AWS Load Balancer Controller). Os workloads da aplicacao NAO
# passam mais pelo Terraform - vao pelo Helm/CI-CD.
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# kubectl: mesma autenticacao do helm. Usado apenas para aplicar os CRDs da
# Gateway API (ver gateway-crds.tf), pre-requisito do LB Controller no modo L7.
provider "kubectl" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}