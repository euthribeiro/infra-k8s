# =============================================================================
# IRSA (IAM Roles for Service Accounts): permite que pods do cluster assumam
# roles IAM sem chaves estaticas. Base para o EBS CSI Driver (volumes) e para o
# AWS Load Balancer Controller (ALB via Gateway API).
# =============================================================================

# ----------------------------------------------------------------------------
# OIDC provider do cluster: liga o emissor OIDC do EKS ao IAM.
# ----------------------------------------------------------------------------
data "tls_certificate" "oidc" {
  url = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc" {
  url             = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
}

locals {
  # Emissor sem o "https://" -> usado nas condicoes das trust policies.
  oidc_issuer_host = replace(aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")
}

# ----------------------------------------------------------------------------
# Role IRSA do EBS CSI Driver.
# Service account: system:serviceaccount:kube-system:ebs-csi-controller-sa
# Sem essa role/permissao, os PVCs (ex.: do Postgres) ficam em Pending.
# ----------------------------------------------------------------------------
resource "aws_iam_role" "ebs_csi" {
  name = "eks-${var.projectName}-ebs-csi"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.oidc.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_issuer_host}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${local.oidc_issuer_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ----------------------------------------------------------------------------
# Role IRSA do AWS Load Balancer Controller.
# Service account: system:serviceaccount:kube-system:aws-load-balancer-controller
# A policy (alb-controller-iam-policy.json) e a oficial do controller e inclui
# acm:ListCertificates / acm:DescribeCertificate (descoberta do cert por hostname).
# ----------------------------------------------------------------------------
resource "aws_iam_policy" "lb_controller" {
  name        = "eks-${var.projectName}-lb-controller"
  description = "Policy oficial do AWS Load Balancer Controller"
  policy      = file("${path.module}/alb-controller-iam-policy.json")
}

resource "aws_iam_role" "lb_controller" {
  name = "eks-${var.projectName}-lb-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.oidc.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_issuer_host}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${local.oidc_issuer_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}
