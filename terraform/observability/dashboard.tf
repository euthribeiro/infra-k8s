resource "newrelic_one_dashboard" "wrench" {
  name        = "Wrench Auto Repair"
  permissions = "public_read_only"

  page {
    name = "Negócio"

    widget_billboard {
      title  = "Ordens de serviço criadas hoje"
      row    = 1
      column = 1
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) AS 'OS criadas' FROM Span WHERE ${local.filtro_servico} AND span.kind = 'server' AND http.route LIKE '%ordem-servico' AND http.request.method = 'POST' AND ${local.status_http} < 400 SINCE today"
      }
    }

    widget_bar {
      title  = "Volume diário de ordens de serviço"
      row    = 1
      column = 5
      width  = 8
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) AS 'OS criadas' FROM Span WHERE ${local.filtro_servico} AND span.kind = 'server' AND http.route LIKE '%ordem-servico' AND http.request.method = 'POST' AND ${local.status_http} < 400 SINCE 30 days ago TIMESERIES 1 day"
      }
    }

    widget_line {
      title  = "Tempo médio de execução por status (minutos)"
      row    = 4
      column = 1
      width  = 8
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT average(ordemservico.diagnostico.duration) / 60000 AS 'Diagnóstico', average(ordemservico.execucao.duration) / 60000 AS 'Execução', average(ordemservico.entrega.duration) / 60000 AS 'Finalização' FROM Metric WHERE ${local.filtro_servico} SINCE 7 days ago TIMESERIES 1 hour"
      }
    }

    widget_billboard {
      title  = "Tempo médio atual por status (minutos)"
      row    = 4
      column = 9
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT latest(ordemservico.diagnostico.duration) / 60000 AS 'Diagnóstico', latest(ordemservico.execucao.duration) / 60000 AS 'Execução', latest(ordemservico.entrega.duration) / 60000 AS 'Finalização' FROM Metric WHERE ${local.filtro_servico} SINCE 30 minutes ago"
      }
    }

    widget_line {
      title  = "Falhas no processamento de ordens de serviço"
      row    = 7
      column = 1
      width  = 8
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT sum(ordemservico.processamento.falhas) FROM Metric WHERE ${local.filtro_servico} FACET comando SINCE 1 day ago TIMESERIES 15 minutes"
      }
    }

    widget_table {
      title  = "Falhas por comando e tipo de erro"
      row    = 7
      column = 9
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT sum(ordemservico.processamento.falhas) AS 'Falhas' FROM Metric WHERE ${local.filtro_servico} FACET comando, tipo_erro SINCE 7 days ago"
      }
    }
  }

  page {
    name = "API"

    widget_line {
      title  = "Latência p50, p95 e p99 (ms)"
      row    = 1
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT percentile(duration.ms, 50, 95, 99) FROM Span WHERE ${local.filtro_servico} AND span.kind = 'server' SINCE 3 hours ago TIMESERIES"
      }
    }

    widget_line {
      title  = "Throughput (requisições por minuto)"
      row    = 1
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT rate(count(*), 1 minute) AS 'Requisições' FROM Span WHERE ${local.filtro_servico} AND span.kind = 'server' SINCE 3 hours ago TIMESERIES"
      }
    }

    widget_table {
      title  = "Latência p95 por rota (ms)"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT percentile(duration.ms, 95) AS 'p95 (ms)', count(*) AS 'Requisições' FROM Span WHERE ${local.filtro_servico} AND span.kind = 'server' AND http.route IS NOT NULL FACET http.route SINCE 3 hours ago LIMIT 20"
      }
    }

    widget_line {
      title  = "Taxa de erro 5xx (%)"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT percentage(count(*), WHERE ${local.status_http} >= 500) AS 'Erro 5xx (%)' FROM Span WHERE ${local.filtro_servico} AND span.kind = 'server' SINCE 1 day ago TIMESERIES 1 hour"
      }
    }

    widget_table {
      title  = "Erros por rota das operações de ordem de serviço"
      row    = 7
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) AS 'Erros' FROM Span WHERE ${local.filtro_servico} AND span.kind = 'server' AND ${local.status_http} >= 500 AND (${local.rotas_ordem_servico}) FACET http.route, ${local.status_http} SINCE 1 day ago"
      }
    }
  }

  page {
    name = "Integrações"

    widget_line {
      title  = "Falhas em chamadas HTTP de saída (SES e serviços externos)"
      row    = 1
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) FROM Span WHERE ${local.filtro_servico} AND span.kind = 'client' AND db.system IS NULL AND (otel.status_code = 'ERROR' OR ${local.status_http} >= 400) FACET server.address SINCE 1 day ago TIMESERIES 1 hour"
      }
    }

    widget_line {
      title  = "Falhas de banco de dados"
      row    = 1
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) FROM Span WHERE ${local.filtro_servico} AND db.system IS NOT NULL AND otel.status_code = 'ERROR' FACET db.name SINCE 1 day ago TIMESERIES 1 hour"
      }
    }

    widget_table {
      title  = "Logs de erro da aplicação"
      row    = 4
      column = 1
      width  = 8
      height = 4

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) AS 'Erros' FROM Log WHERE ${local.filtro_servico} AND (level = 'Error' OR severity.text = 'Error') FACET message SINCE 1 day ago LIMIT 50"
      }
    }

    widget_billboard {
      title  = "Duração média das chamadas de saída (ms)"
      row    = 4
      column = 9
      width  = 4
      height = 4

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT average(duration.ms) AS 'HTTP de saída', filter(average(duration.ms), WHERE db.system IS NOT NULL) AS 'Banco' FROM Span WHERE ${local.filtro_servico} AND span.kind = 'client' SINCE 1 hour ago"
      }
    }
  }

  page {
    name = "Kubernetes"

    widget_line {
      title  = "CPU por pod da API (cores)"
      row    = 1
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT average(cpuUsedCores) AS 'CPU (cores)' FROM K8sPodSample WHERE ${local.filtro_pods_api} FACET podName SINCE 3 hours ago TIMESERIES"
      }
    }

    widget_line {
      title  = "Memória por pod da API (MB)"
      row    = 1
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT average(memoryUsedBytes) / 1e6 AS 'Memória (MB)' FROM K8sPodSample WHERE ${local.filtro_pods_api} FACET podName SINCE 3 hours ago TIMESERIES"
      }
    }

    widget_line {
      title  = "CPU e memória dos nós"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT average(cpuUsedCores) AS 'CPU (cores)', average(memoryUsedBytes) / 1e9 AS 'Memória (GB)' FROM K8sNodeSample WHERE ${local.filtro_cluster} FACET nodeName SINCE 3 hours ago TIMESERIES"
      }
    }

    widget_line {
      title  = "Réplicas da API (HPA)"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT uniqueCount(podName) AS 'Pods' FROM K8sPodSample WHERE ${local.filtro_pods_api} AND status = 'Running' FACET namespaceName SINCE 3 hours ago TIMESERIES"
      }
    }

    widget_line {
      title  = "Restarts de container da API"
      row    = 7
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT sum(restartCountDelta) AS 'Restarts' FROM K8sContainerSample WHERE ${local.filtro_pods_api} FACET podName SINCE 1 day ago TIMESERIES 1 hour"
      }
    }

    widget_billboard {
      title  = "Pods da API em Running (%)"
      row    = 7
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT percentage(count(*), WHERE status = 'Running') AS 'Uptime (%)' FROM K8sPodSample WHERE ${local.filtro_pods_api} SINCE 1 day ago"
      }
    }
  }

  page {
    name = "Healthcheck"

    widget_billboard {
      title  = "Disponibilidade externa de /health (24h)"
      row    = 1
      column = 1
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT percentage(count(*), WHERE result = 'SUCCESS') AS 'Uptime (%)' FROM SyntheticCheck WHERE ${local.filtro_synthetic} SINCE 1 day ago"
      }
    }

    widget_line {
      title  = "Tempo de resposta de /health por localização (ms)"
      row    = 1
      column = 5
      width  = 8
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT average(duration) FROM SyntheticCheck WHERE ${local.filtro_synthetic} FACET locationLabel SINCE 1 day ago TIMESERIES"
      }
    }

    widget_table {
      title  = "Execuções com falha"
      row    = 4
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT timestamp, locationLabel, error, duration FROM SyntheticCheck WHERE ${local.filtro_synthetic} AND result = 'FAILED' SINCE 7 days ago LIMIT 50"
      }
    }
  }
}
