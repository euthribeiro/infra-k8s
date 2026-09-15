# =============================================================================
# Controllers e addons de cluster instalados pelo Terraform.
#   - EBS CSI Driver    -> provisiona os volumes EBS (PVCs do Postgres/gp3)
#   - Metrics Server    -> alimenta o HPA (CPU) e o `kubectl top`
#   - AWS LB Controller -> cria o ALB a partir do Gateway/HTTPRoute (Gateway API)
# =============================================================================

# ----------------------------------------------------------------------------
# Metrics Server (add-on da comunidade do EKS). Necessario para o HPA escalar
# por CPU. Nao chama a API da AWS, entao NAO precisa de IRSA.
# ----------------------------------------------------------------------------
resource "aws_eks_addon" "metrics_server" {
  cluster_name = aws_eks_cluster.cluster.name
  addon_name   = "metrics-server"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.node_group]
}

# ----------------------------------------------------------------------------
# EBS CSI Driver como addon gerenciado do EKS, usando a role IRSA de irsa.tf.
# ----------------------------------------------------------------------------
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.cluster.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi.arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.node_group,
    aws_iam_role_policy_attachment.ebs_csi,
  ]
}

# ----------------------------------------------------------------------------
# AWS Load Balancer Controller via Helm (repo oficial eks-charts).
# O service account e criado pelo chart com a anotacao IRSA da role de irsa.tf.
# region e vpcId sao passados explicitamente (recomendado pela AWS).
#
# Os CRDs da Gateway API (pre-requisito do modo L7) sao instalados em
# gateway-crds.tf e entram no depends_on abaixo, garantindo que o controller
# suba DEPOIS deles - assim o sub-controller de Gateway ja nasce habilitado.
# ----------------------------------------------------------------------------
resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lbc_chart_version
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.cluster.name
  }

  set {
    name  = "region"
    value = var.region_default
  }

  set {
    name  = "vpcId"
    value = aws_vpc.vpc_wrench.id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.lb_controller.arn
  }

  depends_on = [
    aws_eks_node_group.node_group,
    aws_eks_access_policy_association.access_entry_association,
    aws_iam_role_policy_attachment.lb_controller,
    kubectl_manifest.gateway_api_crds,
    kubectl_manifest.aws_gateway_crds,
  ]
}
