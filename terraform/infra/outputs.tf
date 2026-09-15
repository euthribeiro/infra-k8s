output "cluster_name" {
  description = "Nome do cluster EKS (usar em: aws eks update-kubeconfig --name ...)"
  value       = aws_eks_cluster.cluster.name
}

output "cluster_endpoint" {
  description = "Endpoint da API do cluster EKS"
  value       = aws_eks_cluster.cluster.endpoint
}

output "region" {
  description = "Regiao AWS (util para o CI/CD)"
  value       = var.region_default
}

output "vpc_id" {
  description = "ID da VPC (util para debug e para o LB Controller)"
  value       = aws_vpc.vpc_wrench.id
}

# Consumido pelo repositorio infra-db (stack rds/) para posicionar o DB subnet
# group e o security group do Postgres dentro desta VPC.
output "public_subnet_ids" {
  description = "IDs das subnets publicas da VPC"
  value       = aws_subnet.public_subnet[*].id
}

output "cluster_oidc_issuer" {
  description = "Emissor OIDC do cluster (base para as roles IRSA)"
  value       = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

output "acm_certificate_arn" {
  description = "ARN do certificado ACM da aplicacao (HTTPS)"
  value       = aws_acm_certificate.app.arn
}

output "lb_controller_role_arn" {
  description = "ARN da role IRSA do AWS Load Balancer Controller"
  value       = aws_iam_role.lb_controller.arn
}

# Consumido pelo state terraform/dns/ (via terraform_remote_state) para criar
# os CNAMEs da aplicacao apontando para o ALB do Gateway.
output "app_hostnames" {
  description = "Hostnames publicos da aplicacao (devem casar com o Gateway/HTTPRoute e o ACM)"
  value       = var.acm_domains
}

# OIDC provider do cluster: consumido pelo state terraform/email/ (via
# terraform_remote_state) para montar a trust policy da role IRSA da app.
output "oidc_provider_arn" {
  description = "ARN do OIDC provider do cluster EKS (base para roles IRSA de apps)"
  value       = aws_iam_openid_connect_provider.oidc.arn
}

output "oidc_provider_host" {
  description = "Host do emissor OIDC (sem https://) para as condicoes sub/aud das trust policies"
  value       = local.oidc_issuer_host
}
