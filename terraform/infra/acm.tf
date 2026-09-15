# =============================================================================
# HTTPS: certificado ACM + validacao por DNS no Cloudflare.
#
# O certificado precisa estar na MESMA regiao do ALB (us-east-1, ver
# var.region_default) - o provider aws padrao ja atende, sem alias.
#
# O AWS Load Balancer Controller descobre este certificado pelo HOSTNAME do
# listener HTTPS do Gateway (nao usa certificateRefs). Por isso os dominios de
# var.acm_domains devem casar com os hostnames do Gateway/HTTPRoute do Helm.
# =============================================================================

resource "aws_acm_certificate" "app" {
  domain_name               = var.acm_domains[0]
  subject_alternative_names = slice(var.acm_domains, 1, length(var.acm_domains))
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge({ Name = "acm-${var.projectName}" }, var.main_tags)
}

# Registros CNAME de validacao do ACM criados no Cloudflare (um por dominio).
resource "cloudflare_dns_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = var.cloudflare_zone_id
  name    = trimsuffix(each.value.name, ".")
  type    = each.value.type
  content = trimsuffix(each.value.value, ".")
  proxied = false # validacao ACM nao pode passar pelo proxy do Cloudflare
  ttl     = 1
}

# Espera a validacao concluir antes de o certificado ser considerado utilizavel.
resource "aws_acm_certificate_validation" "app" {
  certificate_arn         = aws_acm_certificate.app.arn
  validation_record_fqdns = [for r in cloudflare_dns_record.acm_validation : r.name]
}
