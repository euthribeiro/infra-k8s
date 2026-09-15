# Cloudflare autenticado por API token.
# ATENCAO: diferente das outras stacks (que so editam DNS), esta precisa de um
# token com permissoes de ACCOUNT: "Cloudflare Tunnel: Edit" e "Access: Apps and
# Policies: Edit" (alem de Zone.DNS:Edit). Defina como variavel do workspace HCP.
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
