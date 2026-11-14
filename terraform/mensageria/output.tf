output "topicos" {
  description = "ARNs dos topicos SNS, para a variavel Sns__TopicArn de cada servico."
  value       = { for chave, topico in aws_sns_topic.eventos : chave => topico.arn }
}

output "filas" {
  description = "URLs das filas SQS, para a variavel Sqs__QueueUrl de cada servico."
  value       = { for nome, fila in aws_sqs_queue.fila : nome => fila.url }
}

output "filas_arns" {
  description = "ARNs das filas SQS."
  value       = { for nome, fila in aws_sqs_queue.fila : nome => fila.arn }
}

output "dlqs" {
  description = "Nomes das DLQs, usados nas condicoes de alerta do New Relic."
  value       = { for nome, dlq in aws_sqs_queue.dlq : nome => dlq.name }
}

output "roles_irsa" {
  description = "ARNs das roles IRSA, para serviceAccount.roleArn de cada chart Helm."
  value       = { for chave, role in aws_iam_role.servico : chave => role.arn }
}

output "os_topic_arn" {
  description = "Topico do OS Service (Sns__TopicArn do os-service)."
  value       = aws_sns_topic.eventos["os"].arn
}

output "os_queue_url" {
  description = "Fila da Saga no OS Service (Sqs__QueueUrl do os-service)."
  value       = aws_sqs_queue.fila["${var.prefixo}-os-saga"].url
}

output "os_role_arn" {
  description = "Role IRSA do OS Service (serviceAccount.roleArn do chart wrench-api)."
  value       = aws_iam_role.servico["os"].arn
}
