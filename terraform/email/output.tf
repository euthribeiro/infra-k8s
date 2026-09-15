output "ses_configuration_set_name" {
  description = "Nome do SES configuration set."
  value       = aws_ses_configuration_set.config_set.name
}

output "ses_domain_identity_arn" {
  description = "ARN da domain identity do SES."
  value       = aws_ses_domain_identity.domain_identity.arn
}

output "dkim_tokens" {
  description = "Tokens de DKIM gerados pelo SES."
  value       = aws_ses_domain_dkim.dkim_identity.dkim_tokens
}

output "cloudflare_dkim_records" {
  description = "Nomes dos CNAMEs de DKIM criados no Cloudflare."
  value       = [for r in cloudflare_dns_record.dkim : r.name]
}

output "domain_verification_status" {
  description = "Status da verificacao do dominio no SES."
  value       = aws_ses_domain_identity_verification.domain_identity_verification.id
}

# Credenciais da app (so quando create_smtp_user = true). SECRETAS.
output "app_ses_access_key_id" {
  description = "AWS Access Key ID para a app enviar via SES."
  value       = var.create_smtp_user ? aws_iam_access_key.app_ses[0].id : null
}

output "app_ses_secret_access_key" {
  description = "AWS Secret Access Key para a app (use com `terraform output -raw`)."
  value       = var.create_smtp_user ? aws_iam_access_key.app_ses[0].secret : null
  sensitive   = true
}
# ARN da role IRSA (so quando create_irsa_role = true). NAO e secreto:
# e injetado no chart via `--set serviceAccount.roleArn=$(terraform output -raw ...)`.
output "app_ses_irsa_role_arn" {
  description = "ARN da role IRSA que a ServiceAccount da app assume para enviar via SES."
  value       = var.create_irsa_role ? aws_iam_role.app_ses_irsa[0].arn : null
}
