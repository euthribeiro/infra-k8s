# =============================================================================
# Alertas da Saga distribuida (Fase 4). As condicoes olham os contadores que os
# tres microsservicos publicam por OpenTelemetry, com temporalidade delta.
# =============================================================================

resource "newrelic_nrql_alert_condition" "saga_mensagem_na_dlq" {
  policy_id                    = newrelic_alert_policy.wrench.id
  type                         = "static"
  name                         = "DLQ da Saga com mensagens"
  description                  = "Mensagem da Saga esgotou as tentativas de entrega e foi para a dead-letter queue (contador saga.mensagem.dlq)."
  enabled                      = true
  violation_time_limit_seconds = 86400
  aggregation_window           = 60
  aggregation_method           = "event_flow"
  aggregation_delay            = 120
  fill_option                  = "static"
  fill_value                   = 0

  nrql {
    query = "SELECT sum(saga.mensagem.dlq) FROM Metric WHERE ${local.filtro_saga}"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 300
    threshold_occurrences = "at_least_once"
  }
}

resource "newrelic_nrql_alert_condition" "saga_falha_no_consumo" {
  policy_id                    = newrelic_alert_policy.wrench.id
  type                         = "static"
  name                         = "Falha no consumo de mensagem da Saga"
  description                  = "Consumidor levantou excecao ao tratar a mensagem; ela volta para a fila e tende a DLQ (contador saga.mensagem.falha)."
  enabled                      = true
  violation_time_limit_seconds = 86400
  aggregation_window           = 60
  aggregation_method           = "event_flow"
  aggregation_delay            = 120
  fill_option                  = "static"
  fill_value                   = 0

  nrql {
    query = "SELECT sum(saga.mensagem.falha) FROM Metric WHERE ${local.filtro_saga}"
  }

  critical {
    operator              = "above"
    threshold             = 2
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

resource "newrelic_nrql_alert_condition" "saga_timeout" {
  policy_id                    = newrelic_alert_policy.wrench.id
  type                         = "static"
  name                         = "Etapa da Saga expirou por timeout"
  description                  = "Uma etapa da Saga passou do prazo sem resposta e entrou em compensacao (contador saga.timeout)."
  enabled                      = true
  violation_time_limit_seconds = 86400
  aggregation_window           = 300
  aggregation_method           = "event_flow"
  aggregation_delay            = 120
  fill_option                  = "static"
  fill_value                   = 0

  nrql {
    query = "SELECT sum(saga.timeout) FROM Metric WHERE ${local.filtro_saga}"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 300
    threshold_occurrences = "at_least_once"
  }
}

resource "newrelic_nrql_alert_condition" "saga_outbox_represada" {
  policy_id                    = newrelic_alert_policy.wrench.id
  type                         = "static"
  name                         = "Outbox da Saga represado"
  description                  = "Mensagens pendentes no outbox transacional nao estao sendo publicadas no SNS (gauge saga.outbox.pendentes)."
  enabled                      = true
  violation_time_limit_seconds = 86400
  aggregation_window           = 60
  aggregation_method           = "event_flow"
  aggregation_delay            = 120

  nrql {
    query = "SELECT latest(saga.outbox.pendentes) FROM Metric WHERE ${local.filtro_saga}"
  }

  critical {
    operator              = "above"
    threshold             = 50
    threshold_duration    = 600
    threshold_occurrences = "all"
  }
}

resource "newrelic_nrql_alert_condition" "saga_duracao" {
  policy_id                    = newrelic_alert_policy.wrench.id
  type                         = "static"
  name                         = "Saga demorando a fechar"
  description                  = "Percentil 95 do tempo entre o inicio e o desfecho da Saga da ordem de servico."
  enabled                      = true
  violation_time_limit_seconds = 86400
  aggregation_window           = 300
  aggregation_method           = "event_flow"
  aggregation_delay            = 120

  nrql {
    query = "SELECT percentile(saga.duracao, 95) FROM Metric WHERE ${local.filtro_saga}"
  }

  critical {
    operator              = "above"
    threshold             = var.saga_duracao_p95_limite_ms
    threshold_duration    = 900
    threshold_occurrences = "all"
  }
}
