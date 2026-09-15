locals {
  filtro_servico      = "service.name = '${var.service_name}'"
  filtro_pods_api     = "clusterName = '${var.cluster_name}' AND podName LIKE '${var.api_pod_prefix}%'"
  filtro_cluster      = "clusterName = '${var.cluster_name}'"
  nome_synthetic      = "Wrench API - healthcheck"
  filtro_synthetic    = "monitorName = '${local.nome_synthetic}'"
  status_http         = "http.response.status_code"
  rotas_ordem_servico = "http.route LIKE '%ordem-servico%' OR http.route LIKE '%diagnostico%' OR http.route LIKE '%orcamento%'"
}
