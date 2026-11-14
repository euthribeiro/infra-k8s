# Tabelas DynamoDB do execucao-service (fila de execucao, outbox e idempotencia)
terraform {
  cloud {
    organization = "bgt3"

    workspaces {
      name = "wrench_auto_repair_execucao_dynamodb"
    }
  }
}
