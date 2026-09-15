resource "newrelic_synthetics_monitor" "healthcheck" {
  name             = local.nome_synthetic
  type             = "SIMPLE"
  status           = "ENABLED"
  period           = "EVERY_5_MINUTES"
  uri              = var.app_health_url
  locations_public = var.synthetic_locations

  validation_string         = "Healthy"
  verify_ssl                = true
  treat_redirect_as_failure = false
}
