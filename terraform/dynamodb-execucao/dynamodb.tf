# Execucoes na fila. O indice por status devolve a fila em ordem de chegada.
resource "aws_dynamodb_table" "execucao" {
  name         = var.execucao_tabela
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ordemServicoId"

  attribute {
    name = "ordemServicoId"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "enfileiradaEm"
    type = "S"
  }

  global_secondary_index {
    name            = "status-enfileiradaEm"
    hash_key        = "status"
    range_key       = "enfileiradaEm"
    projection_type = "ALL"
  }

  tags = var.main_tags
}

# Outbox: eventos de saida gravados na mesma transacao do novo estado e publicados no SNS
# pelo dispatcher. O indice por status localiza as mensagens pendentes.
resource "aws_dynamodb_table" "execucao_outbox" {
  name         = var.execucao_outbox_tabela
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "criadoEm"
    type = "S"
  }

  global_secondary_index {
    name            = "status-criadoEm"
    hash_key        = "status"
    range_key       = "criadoEm"
    projection_type = "ALL"
  }

  tags = var.main_tags
}

# Idempotencia: um registro por mensagem consumida, expirado automaticamente pelo TTL.
resource "aws_dynamodb_table" "execucao_idempotencia" {
  name         = var.execucao_idempotencia_tabela
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "messageId"

  attribute {
    name = "messageId"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = var.main_tags
}
