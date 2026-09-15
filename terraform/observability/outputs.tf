output "dashboard_permalink" {
  description = "Link do dashboard Wrench Auto Repair no New Relic."
  value       = newrelic_one_dashboard.wrench.permalink
}

output "alert_policy_id" {
  description = "ID da politica de alertas Wrench Auto Repair."
  value       = newrelic_alert_policy.wrench.id
}

output "synthetic_monitor_id" {
  description = "ID do synthetic monitor do healthcheck da API."
  value       = newrelic_synthetics_monitor.healthcheck.id
}
