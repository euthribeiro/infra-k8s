# Token do conector do tunnel. Consumido pelo CI (deploy) e injetado no chart
# Helm como Secret (cloudflared-token). SENSIVEL: use `terraform output -raw`.
output "tunnel_token" {
  description = "Token do conector cloudflared."
  value       = local.tunnel_token
  sensitive   = true
}

output "tunnel_id" {
  description = "ID do Cloudflare Tunnel."
  value       = cloudflare_zero_trust_tunnel_cloudflared.structurizr.id
}

output "hostname" {
  description = "Hostname publico do Structurizr."
  value       = var.hostname
}
