# =============================================================================
# Uma fila por consumidor, cada uma com a sua DLQ. Mensagens que esgotam as
# tentativas de entrega param na DLQ, onde o alerta do New Relic as observa.
# =============================================================================

resource "aws_sqs_queue" "dlq" {
  for_each = local.nomes_filas

  name                      = "${each.value}-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds
  tags                      = var.main_tags
}

resource "aws_sqs_queue" "fila" {
  for_each = local.nomes_filas

  name                       = each.value
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.value].arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = var.main_tags
}

# Permite que apenas os topicos deste stack entreguem mensagens nas filas.
data "aws_iam_policy_document" "fila" {
  for_each = local.nomes_filas

  statement {
    sid    = "PermiteEntregaDosTopicosDaSaga"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.fila[each.value].arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [for topico in aws_sns_topic.eventos : topico.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "fila" {
  for_each = local.nomes_filas

  queue_url = aws_sqs_queue.fila[each.value].id
  policy    = data.aws_iam_policy_document.fila[each.value].json
}

# A assinatura liga topico e fila e o filter policy descarta, antes da entrega,
# o que aquele consumidor nao trata.
resource "aws_sns_topic_subscription" "fila" {
  for_each = local.filas

  topic_arn            = aws_sns_topic.eventos[each.value.topico].arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.fila[each.value.nome].arn
  raw_message_delivery = true

  filter_policy_scope = "MessageAttributes"
  filter_policy = jsonencode({
    tipo = each.value.tipos
  })
}
