resource "aws_security_group" "cluster-sg" {
  name = "fcj-cluster-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 0
    to_port = 0
    protocol = "ALL"
    cidr_blocks = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "ALL"
    cidr_blocks = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_cluster" "this" {
  name = "fcj-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version = "1.29"

  vpc_config {
    subnet_ids = [ module.vpc.private_subnets[0], module.vpc.public_subnets[0], module.vpc.private_subnets[1], module.vpc.public_subnets[1] ]
    endpoint_private_access = true
    endpoint_public_access = true
    security_group_ids = [ aws_security_group.cluster-sg.id ]
    public_access_cidrs = [ "0.0.0.0/0" ]
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  

  depends_on = [ 
    aws_security_group.cluster-sg
   ]
}

# resource "aws_eks_addon" "coredns" {
#   cluster_name                = aws_eks_cluster.this.name
#   addon_name                  = "coredns"
#   addon_version               = "v1.11.1-eksbuild.4" #e.g., previous version v1.9.3-eksbuild.3 and the new version is v1.10.1-eksbuild.1
#   resolve_conflicts_on_update = "PRESERVE"
# }

resource "aws_eks_addon" "vpc-cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"
  addon_version = "v1.16.0-eksbuild.1"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "kube-proxy" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "kube-proxy"
  addon_version = "v1.29.0-eksbuild.1"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_node_group" "node-1" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "node-group-1"
  node_role_arn   = aws_iam_role.node_group_role.arn
  subnet_ids      = [ module.vpc.private_subnets[0], module.vpc.public_subnets[0], module.vpc.private_subnets[1], module.vpc.public_subnets[1] ]
  instance_types = [ "t2.small" ]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
  ]
}
