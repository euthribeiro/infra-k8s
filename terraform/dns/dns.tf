# =============================================================================
# State do DNS da aplicacao.
#
# Le o state da infra (cluster_name e hostnames), encontra o ALB que o AWS Load
# Balancer Controller provisionou para o Gateway e cria/atualiza os CNAMEs no
# Cloudflare apontando para ele.
#
# Este state SO deve ser aplicado depois que o Gateway ja tem endereco (ALB
# criado). No CI, isso e garantido esperando o Gateway ganhar endereco antes do
# `terraform -chdir=terraform/dns apply`. Como aqui os recursos estao sempre
# declarados (sem flag), o apply e idempotente: cria na 1a vez, no-op depois.
# =============================================================================

# Outputs da infra (workspace HCP separado).
data "terraform_remote_state" "infra" {
  backend = "remote"

  config = {
    organization = var.tfc_organization
    workspaces = {
      name = var.infra_workspace
    }
  }
}

# ALB provisionado pelo LB Controller para o Gateway. A tag elbv2.k8s.aws/cluster
# identifica o balanceador do cluster; com um unico Gateway, o match e exato.
# (Se houver mais de um ALB no futuro, refine com as tags do stack do Gateway:
#  "gateway.k8s.aws/stack-namespace" e "gateway.k8s.aws/stack-name".)
data "aws_lb" "gateway" {
  tags = {
    "elbv2.k8s.aws/cluster" = data.terraform_remote_state.infra.outputs.cluster_name
  }
}

# Um CNAME por hostname da aplicacao (ignorando curingas), apontando para o ALB.
resource "cloudflare_dns_record" "app" {
  for_each = toset([
    for d in data.terraform_remote_state.infra.outputs.app_hostnames : d
    if !startswith(d, "*.")
  ])

  zone_id = var.cloudflare_zone_id
  name    = each.value
  type    = "CNAME"
  content = data.aws_lb.gateway.dns_name
  proxied = false # DNS-only: TLS termina no ALB com o cert do ACM
  ttl     = 1     # 1 = "Auto" (obrigatorio quando proxied = false)
}
