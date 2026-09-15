# Secret do tunnel (32 bytes aleatorios). E a base do token do conector.
resource "random_bytes" "tunnel_secret" {
  length = 32
}

# Tunnel gerenciado pela Cloudflare (config_src = "cloudflare").
resource "cloudflare_zero_trust_tunnel_cloudflared" "structurizr" {
  account_id    = var.cloudflare_account_id
  name          = var.tunnel_name
  config_src    = "cloudflare"
  tunnel_secret = random_bytes.tunnel_secret.base64
}

# Token do conector cloudflared.
locals {
  tunnel_token = base64encode(jsonencode({
    a = var.cloudflare_account_id
    t = cloudflare_zero_trust_tunnel_cloudflared.structurizr.id
    s = random_bytes.tunnel_secret.base64
  }))
}

# Ingress do tunnel: encaminha o hostname publico para o Service interno do Lite,
# com uma regra catch-all obrigatoria no final.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "structurizr" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.structurizr.id

  config = {
    ingress = [
      {
        hostname = var.hostname
        service  = var.internal_service
      },
      {
        service = "http_status:404"
      }
    ]
  }
}

# CNAME publico (proxied) apontando para o tunnel: <tunnel-id>.cfargotunnel.com
resource "cloudflare_dns_record" "structurizr" {
  zone_id = var.cloudflare_zone_id
  name    = var.subdomain
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.structurizr.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}
