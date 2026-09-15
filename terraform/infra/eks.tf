# =============================================================================
# EKS: cluster, node group e acesso administrativo (access entry).
# =============================================================================

# ----------------------------------------------------------------------------
# Cluster EKS (control plane nas subnets privadas)
# ----------------------------------------------------------------------------
resource "aws_eks_cluster" "cluster" {
  name = "eks-${var.projectName}"

  access_config {
    authentication_mode = "API"
  }

  role_arn = aws_iam_role.cluster.arn
  version  = data.aws_eks_cluster_versions.current.cluster_versions[0].cluster_version

  vpc_config {
    subnet_ids         = aws_subnet.private_subnet[*].id
    security_group_ids = [aws_security_group.sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  ]
}

# ----------------------------------------------------------------------------
# Node group (worker nodes nas subnets privadas)
# ----------------------------------------------------------------------------
resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "nodeg-${var.projectName}"
  node_role_arn   = aws_iam_role.node_group_role.arn
  subnet_ids      = aws_subnet.private_subnet[*].id
  disk_size       = 50
  instance_types  = [var.main_instance_type]

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_role_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_group_role_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_group_role_AmazonEC2ContainerRegistryReadOnly,
  ]
}

# ----------------------------------------------------------------------------
# Access entry: da ao usuario IAM acesso de admin ao cluster
# ----------------------------------------------------------------------------
resource "aws_eks_access_entry" "access_entry" {
  cluster_name  = aws_eks_cluster.cluster.name
  principal_arn = data.aws_iam_user.main_iam_user.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "access_entry_association" {
  cluster_name  = aws_eks_cluster.cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.access_entry.principal_arn

  access_scope {
    type = "cluster"
  }
}
