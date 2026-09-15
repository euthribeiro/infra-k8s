output "gateway_alb_dns_name" {
  description = "Hostname do ALB do Gateway (alvo dos CNAMEs)."
  value       = data.aws_lb.gateway.dns_name
}

output "app_records" {
  description = "CNAMEs criados para a aplicacao."
  value       = [for r in cloudflare_dns_record.app : r.name]
}
