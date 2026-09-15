# Le o OIDC provider do cluster (state da infra) para montar a trust policy
# da role IRSA. Requer state sharing do workspace da infra para este workspace.
data "terraform_remote_state" "infra" {
  backend = "remote"

  config = {
    organization = var.tfc_organization
    workspaces = {
      name = var.infra_workspace
    }
  }
}
