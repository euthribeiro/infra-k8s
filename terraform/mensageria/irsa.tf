# =============================================================================
# Uma role IRSA por servico. A ServiceAccount do chart recebe o ARN na anotacao
# eks.amazonaws.com/role-arn e o SDK da AWS assume a role sem chave estatica.
# Cada servico so publica no proprio topico e so consome da propria fila.
# =============================================================================

data "aws_iam_policy_document" "assume" {
  for_each = local.servicos

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:sub"
      values   = [for namespace in var.k8s_namespaces : "system:serviceaccount:${namespace}:${each.value.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "servico" {
  for_each = local.servicos

  name               = "${var.prefixo}-${each.key}-mensageria"
  assume_role_policy = data.aws_iam_policy_document.assume[each.key].json
  tags               = var.main_tags
}

data "aws_iam_policy_document" "mensageria" {
  for_each = local.servicos

  statement {
    sid       = "PublicarNoTopicoDoServico"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [for topico in each.value.publica : aws_sns_topic.eventos[topico].arn]
  }

  statement {
    sid    = "ConsumirDaFilaDoServico"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = [for fila in each.value.consome : aws_sqs_queue.fila[fila].arn]
  }
}

resource "aws_iam_role_policy" "mensageria" {
  for_each = local.servicos

  name   = "mensageria"
  role   = aws_iam_role.servico[each.key].id
  policy = data.aws_iam_policy_document.mensageria[each.key].json
}

# O execucao-service grava estado, outbox e idempotencia no DynamoDB numa unica
# TransactWriteItems e le a fila pelo indice secundario.
data "aws_iam_policy_document" "dynamodb_execucao" {
  statement {
    sid    = "TabelasDoExecucaoService"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:TransactWriteItems",
      "dynamodb:DescribeTable",
    ]
    resources = [
      local.tabelas_dynamodb,
      "${local.tabelas_dynamodb}/index/*",
      "${local.tabelas_dynamodb}-outbox",
      "${local.tabelas_dynamodb}-outbox/index/*",
      "${local.tabelas_dynamodb}-idempotencia",
    ]
  }
}

resource "aws_iam_role_policy" "dynamodb_execucao" {
  name   = "dynamodb"
  role   = aws_iam_role.servico["execucao"].id
  policy = data.aws_iam_policy_document.dynamodb_execucao.json
}

# O OS Service envia o e-mail de acompanhamento da OS pela mesma ServiceAccount
# que assume esta role, entao ela acumula o ses:SendEmail que antes vinha da
# role criada no stack email/. Uma ServiceAccount so pode apontar para uma role.
data "aws_iam_policy_document" "ses_send" {
  statement {
    sid    = "EnvioDeEmailPeloSES"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ses_send" {
  count = var.ses_send_allowed ? 1 : 0

  name   = "ses-send"
  role   = aws_iam_role.servico["os"].id
  policy = data.aws_iam_policy_document.ses_send.json
}
