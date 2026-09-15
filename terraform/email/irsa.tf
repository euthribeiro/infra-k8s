# =============================================================================
# IRSA: a aplicacao envia via SES assumindo uma role IAM pela ServiceAccount do
# pod (OIDC), sem chaves estaticas. Substitui o IAM user + access key.
#
# A trust policy libera exatamente system:serviceaccount:<ns>:<sa>. O <ns>/<sa>
# devem casar com o chart Helm (serviceAccount.name / namespace).
# =============================================================================

locals {
  oidc_provider_arn  = data.terraform_remote_state.infra.outputs.oidc_provider_arn
  oidc_provider_host = data.terraform_remote_state.infra.outputs.oidc_provider_host
}

resource "aws_iam_role" "app_ses_irsa" {
  count = var.create_irsa_role ? 1 : 0
  name  = "${var.configuration_set_name}-app-ses-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_host}:sub" = "system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account}"
          "${local.oidc_provider_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

# Reaproveita o mesmo documento de policy (ses:SendEmail/SendRawEmail) do IAM user.
resource "aws_iam_role_policy" "app_ses_irsa" {
  count  = var.create_irsa_role ? 1 : 0
  name   = "ses-send"
  role   = aws_iam_role.app_ses_irsa[0].id
  policy = data.aws_iam_policy_document.ses_send.json
}
