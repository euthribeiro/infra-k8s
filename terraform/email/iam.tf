# =============================================================================
# Credenciais para a APLICACAO enviar e-mail via SES.
#
# A app (wrench.auto.repair.infra / AwsSesEmailService) usa o SDK da AWS
# (SendEmail), nao SMTP. Entao ela precisa de credenciais AWS com permissao
# ses:SendEmail. Aqui criamos um IAM user dedicado + access key.
# =============================================================================

resource "aws_iam_user" "app_ses" {
  count = var.create_smtp_user ? 1 : 0
  name  = "${var.configuration_set_name}-app-ses"
}

data "aws_iam_policy_document" "ses_send" {
  statement {
    sid    = "AllowSESSend"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "app_ses" {
  count  = var.create_smtp_user ? 1 : 0
  name   = "ses-send"
  user   = aws_iam_user.app_ses[0].name
  policy = data.aws_iam_policy_document.ses_send.json
}

resource "aws_iam_access_key" "app_ses" {
  count = var.create_smtp_user ? 1 : 0
  user  = aws_iam_user.app_ses[0].name
}
