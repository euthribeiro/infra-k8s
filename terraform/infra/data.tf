# =============================================================================
# Data sources: informacoes consultadas na AWS em tempo de execucao.
# =============================================================================

# Zonas de disponibilidade da regiao em uso
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

# Ultima versao do EKS disponivel
data "aws_eks_cluster_versions" "current" {
  default_only = true
}

# Dados do cluster EKS (usado para configurar os providers do Kubernetes)
data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.cluster.name
}

# Token de autenticacao do cluster EKS
data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.cluster.name
}

# Usuario IAM que recebe acesso admin ao cluster (ver eks.tf)
data "aws_iam_user" "main_iam_user" {
  user_name = var.iam_username
}
