output "execucao_tabelas" {
  description = "Nomes das tabelas, para as variaveis Dynamo__Execucao, Dynamo__Outbox e Dynamo__Idempotencia do execucao-service."
  value = {
    execucao     = aws_dynamodb_table.execucao.name
    outbox       = aws_dynamodb_table.execucao_outbox.name
    idempotencia = aws_dynamodb_table.execucao_idempotencia.name
  }
}

output "execucao_tabelas_arns" {
  description = "ARNs das tabelas, para a policy da role IRSA (dynamodb:GetItem, PutItem, UpdateItem, Query e TransactWriteItems nas tabelas e em <arn>/index/*)."
  value = {
    execucao     = aws_dynamodb_table.execucao.arn
    outbox       = aws_dynamodb_table.execucao_outbox.arn
    idempotencia = aws_dynamodb_table.execucao_idempotencia.arn
  }
}
