output "api_repository_url" {
  value       = aws_ecr_repository.wrench_repo["api"].repository_url
  description = "URL do repositório ECR para API"
}

output "chart_repository" {
  # dirname devolve o caminho pai (.../wrench/charts). O `helm push` anexa o
  # nome do chart (wrench-api), resultando em .../wrench/charts/wrench-api.
  value = dirname(aws_ecr_repository.wrench_repo["charts/wrench-api"].repository_url)
}

output "chart_repository_url" {
  value = aws_ecr_repository.wrench_repo["charts/wrench-api"].repository_url
}

output "structurizr_chart_repository" {
  value = dirname(aws_ecr_repository.wrench_repo["charts/structurizr"].repository_url)
}

output "structurizr_chart_repository_url" {
  value = aws_ecr_repository.wrench_repo["charts/structurizr"].repository_url
}

output "billing_repository_url" {
  value       = aws_ecr_repository.wrench_repo["billing-api"].repository_url
  description = "URL do repositório ECR da imagem do billing-service"
}

output "billing_chart_repository" {
  value = dirname(aws_ecr_repository.wrench_repo["charts/wrench-billing"].repository_url)
}

output "billing_chart_repository_url" {
  value = aws_ecr_repository.wrench_repo["charts/wrench-billing"].repository_url
}

output "execucao_repository_url" {
  value       = aws_ecr_repository.wrench_repo["execucao-api"].repository_url
  description = "URL do repositório ECR da imagem do execucao-service"
}

output "execucao_chart_repository" {
  value = dirname(aws_ecr_repository.wrench_repo["charts/wrench-execucao"].repository_url)
}

output "execucao_chart_repository_url" {
  value = aws_ecr_repository.wrench_repo["charts/wrench-execucao"].repository_url
}
