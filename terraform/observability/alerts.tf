resource "newrelic_alert_policy" "wrench" {
  name                = "Wrench Auto Repair"
  incident_preference = "PER_CONDITION"
}

resource "newrelic_nrql_alert_condition" "falha_processamento_ordem_servico" {
  policy_id                    = newrelic_alert_policy.wrench.id
  type                         = "static"
  name                         = "Falha no processamento de ordem de servico"
  description                  = "Comando de ordem de servico terminou em excecao ou erro inesperado (contador ordemservico.processamento.falhas)."
  enabled                      = true
  violation_time_limit_seconds = 86400
  aggregation_window           = 60
  aggregation_method           = "event_flow"
  aggregation_delay            = 120
  fill_option                  = "static"
  fill_value                   = 0

  nrql {
    query = "SELECT sum(ordemservico.processamento.falhas) FROM Metric WHERE ${local.filtro_servico}"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 300
    threshold_occurrences = "at_least_once"
  }
}

resource "newrelic_nrql_alert_condition" "taxa_erro_5xx_api" {
  policy_id                    = newrelic_alert_policy.wrench.id
  type                         = "static"
  name                         = "Taxa de erro 5xx da API"
  description                  = "Percentual de requisicoes da API respondidas com status 5xx."
  enabled                      = true
  violation_time_limit_seconds = 86400
  aggregation_window           = 60
  aggregation_method           = "event_flow"
  aggregation_delay            = 120

  nrql {
    query = "SELECT percentage(count(*), WHERE ${local.status_http} >= 500) FROM Span WHERE ${local.filtro_servico} AND span.kind = 'server'"
  }

  critical {
    operator              = "above"
    threshold             = var.taxa_erro_5xx_limite_percentual
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

resource "newrelic_nrql_alert_condition" "latencia_p95_api" {
  policy_id                    = newrelic_alert_policy.wrench.id
  type                         = "static"
  name                         = "Latencia p95 da API"
  description                  = "Percentil 95 da duracao das requisicoes HTTP atendidas pela API."
  enabled                      = true
  violation_time_limit_seconds = 86400
  aggregation_window           = 60
  aggregation_method           = "event_flow"
  aggregation_delay            = 120

  nrql {
    query = "SELECT percentile(duration.ms, 95) FROM Span WHERE ${local.filtro_servico} AND span.kind = 'server'"
  }

  critical {
    operator              = "above"
    threshold             = var.latencia_p95_limite_ms
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

resource "newrelic_nrql_alert_condition" "restart_pods_api" {
  policy_id                    = newrelic_alert_policy.wrench.id
  type                         = "static"
  name                         = "Restart de pod da API"
  description                  = "Container da API reiniciado, normalmente por falha no liveness probe /health ou OOM."
  enabled                      = true
  violation_time_limit_seconds = 86400
  aggregation_window           = 60
  aggregation_method           = "event_flow"
  aggregation_delay            = 120
  fill_option                  = "static"
  fill_value                   = 0

  nrql {
    query = "SELECT sum(restartCountDelta) FROM K8sContainerSample WHERE ${local.filtro_pods_api}"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 300
    threshold_occurrences = "at_least_once"
  }
}

resource "newrelic_nrql_alert_condition" "healthcheck_indisponivel" {
  policy_id                    = newrelic_alert_policy.wrench.id
  type                         = "static"
  name                         = "Healthcheck externo da API falhando"
  description                  = "Synthetic monitor nao obteve resposta saudavel de /health em duas execucoes seguidas."
  enabled                      = true
  violation_time_limit_seconds = 86400
  aggregation_window           = 300
  aggregation_method           = "event_timer"
  aggregation_timer            = 300

  nrql {
    query = "SELECT filter(count(*), WHERE result = 'FAILED') FROM SyntheticCheck WHERE ${local.filtro_synthetic}"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 600
    threshold_occurrences = "all"
  }
}

resource "newrelic_notification_destination" "email" {
  account_id = var.newrelic_account_id
  name       = "Wrench Auto Repair - e-mail do time"
  type       = "EMAIL"

  property {
    key   = "email"
    value = var.alert_email
  }
}

resource "newrelic_notification_channel" "email" {
  account_id     = var.newrelic_account_id
  name           = "Wrench Auto Repair - e-mail"
  type           = "EMAIL"
  destination_id = newrelic_notification_destination.email.id
  product        = "IINT"

  property {
    key   = "subject"
    value = "[Wrench Auto Repair] {{ issueTitle }}"
  }
}

resource "newrelic_workflow" "wrench" {
  name                  = "Wrench Auto Repair - notificacao de incidentes"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "Politica Wrench Auto Repair"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_alert_policy.wrench.id]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.email.id
  }
}
