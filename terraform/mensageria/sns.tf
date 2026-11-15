# =============================================================================
# Um topico SNS por publicador. Os eventos da Saga trafegam com raw message
# delivery: o corpo da mensagem e o proprio payload JSON do evento e os
# metadados (tipo, correlationId, traceparent) viajam como message attributes.
# =============================================================================

resource "aws_sns_topic" "eventos" {
  for_each = local.topicos

  name = each.value
  tags = var.main_tags
}
