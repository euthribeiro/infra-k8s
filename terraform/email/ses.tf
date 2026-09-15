# =============================================================================
# Amazon SES + DNS no Cloudflare
#
# Fluxo:
#   1. Cria a "domain identity" no SES (o dominio de onde a app envia e-mail).
#   2. Habilita Easy DKIM (SES gera 3 tokens CNAME).
#   3. Publica no Cloudflare:
#        - 1 registro TXT `_amazonses.<dominio>` (prova de posse do dominio);
#        - 3 registros CNAME de DKIM (assinatura das mensagens).
#   4. `aws_ses_domain_identity_verification` espera o SES marcar o dominio como
#      verificado (depende dos registros acima terem propagado).
#
# Todos os registros DNS ficam DNS-only (proxied = false): validacao do SES
# precisa enxergar o valor real, nao o proxy do Cloudflare.
# =============================================================================

# Configuration set (metricas, TLS obrigatorio no envio).
resource "aws_ses_configuration_set" "config_set" {
  name                       = var.configuration_set_name
  reputation_metrics_enabled = var.reputation_metrics_enabled
  sending_enabled            = var.sending_enabled

  delivery_options {
    tls_policy = "Require"
  }

  dynamic "tracking_options" {
    for_each = var.custom_redirect_domain == "" ? [] : [var.custom_redirect_domain]
    content {
      custom_redirect_domain = tracking_options.value
    }
  }
}

# -----------------------------------------------------------------------------
# Identidade do dominio + DKIM
# -----------------------------------------------------------------------------
resource "aws_ses_domain_identity" "domain_identity" {
  domain = var.domain_name
}

resource "aws_ses_domain_dkim" "dkim_identity" {
  domain = aws_ses_domain_identity.domain_identity.domain
}

# -----------------------------------------------------------------------------
# Registros DNS no Cloudflare (provider v5: `content` e STRING, nao lista)
# -----------------------------------------------------------------------------

# TXT de verificacao de posse do dominio: _amazonses.<dominio>
resource "cloudflare_dns_record" "ses_verification" {
  zone_id = var.cloudflare_zone_id
  name    = "_amazonses.${var.domain_name}"
  type    = "TXT"
  ttl     = 1 # 1 = "Auto" (obrigatorio com proxied = false)
  content = aws_ses_domain_identity.domain_identity.verification_token
  proxied = false
}

# 3 CNAMEs de DKIM: <token>._domainkey.<dominio> -> <token>.dkim.amazonses.com
resource "cloudflare_dns_record" "dkim" {
  count = 3 # SES sempre gera 3 tokens de DKIM

  zone_id = var.cloudflare_zone_id
  name    = "${aws_ses_domain_dkim.dkim_identity.dkim_tokens[count.index]}._domainkey.${var.domain_name}"
  type    = "CNAME"
  ttl     = 1
  content = "${aws_ses_domain_dkim.dkim_identity.dkim_tokens[count.index]}.dkim.amazonses.com"
  proxied = false
}

# -----------------------------------------------------------------------------
# Espera o SES confirmar a verificacao do dominio
# -----------------------------------------------------------------------------
resource "aws_ses_domain_identity_verification" "domain_identity_verification" {
  domain = aws_ses_domain_identity.domain_identity.id

  depends_on = [
    cloudflare_dns_record.ses_verification,
    cloudflare_dns_record.dkim,
  ]
}

resource "aws_ses_email_identity" "allowed" {
  for_each = var.allowed_emails
  email    = each.value
}