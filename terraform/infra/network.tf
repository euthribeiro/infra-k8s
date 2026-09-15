# =============================================================================
# Rede: VPC, subnets, internet gateway, NAT gateway, rotas e security group.
# =============================================================================

# ----------------------------------------------------------------------------
# VPC principal
# ----------------------------------------------------------------------------
resource "aws_vpc" "vpc_wrench" {
  cidr_block           = var.cidr_vpc
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# ----------------------------------------------------------------------------
# Subnets publicas (recebem os Load Balancers internet-facing)
# ----------------------------------------------------------------------------
resource "aws_subnet" "public_subnet" {
  count = var.subnet_count

  vpc_id                  = aws_vpc.vpc_wrench.id
  cidr_block              = cidrsubnet(aws_vpc.vpc_wrench.cidr_block, 4, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  # Tags para o cloud provider da AWS descobrir estas subnets ao criar os LBs.
  tags = merge({
    Name                                           = "${var.projectName}-public-${count.index}"
    "kubernetes.io/role/elb"                       = "1"
    "kubernetes.io/cluster/eks-${var.projectName}" = "shared"
  }, var.main_tags)
}

# ----------------------------------------------------------------------------
# Subnets privadas (rodam o cluster EKS e os nodes)
# ----------------------------------------------------------------------------
resource "aws_subnet" "private_subnet" {
  count = var.subnet_count

  vpc_id            = aws_vpc.vpc_wrench.id
  cidr_block        = cidrsubnet(aws_vpc.vpc_wrench.cidr_block, 4, count.index + var.subnet_count)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge({
    Name                                           = "${var.projectName}-private-${count.index}"
    "kubernetes.io/role/internal-elb"              = "1"
    "kubernetes.io/cluster/eks-${var.projectName}" = "shared"
  }, var.main_tags)
}

# ----------------------------------------------------------------------------
# Internet Gateway: entrada/saida publica da VPC
# ----------------------------------------------------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_wrench.id
}

# ----------------------------------------------------------------------------
# NAT Gateway: saida para a internet dos nodes nas subnets privadas
# (necessario para registrar no EKS e puxar imagens de container)
# ----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge({
    Name = "nat-${var.projectName}"
  }, var.main_tags)
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet[0].id

  tags = merge({
    Name = "nat-${var.projectName}"
  }, var.main_tags)

  depends_on = [aws_internet_gateway.igw]
}

# ----------------------------------------------------------------------------
# Tabelas de rota
#   publica  -> 0.0.0.0/0 via Internet Gateway
#   privada  -> 0.0.0.0/0 via NAT Gateway
# (a rota "local" da VPC e criada automaticamente pela AWS)
# ----------------------------------------------------------------------------
resource "aws_route_table" "rt_public" {
  vpc_id = aws_vpc.vpc_wrench.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge({
    Name = "rt-public-${var.projectName}"
  }, var.main_tags)
}

resource "aws_route_table_association" "rt_public_association" {
  count          = var.subnet_count
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.rt_public.id
}

resource "aws_route_table" "rt_private" {
  vpc_id = aws_vpc.vpc_wrench.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = merge({
    Name = "rt-private-${var.projectName}"
  }, var.main_tags)
}

resource "aws_route_table_association" "rt_private_association" {
  count          = var.subnet_count
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.rt_private.id
}

# ----------------------------------------------------------------------------
# Security group do cluster
# ----------------------------------------------------------------------------
resource "aws_security_group" "sg" {
  name        = var.projectName
  description = "Usado para expor services na internet"
  vpc_id      = aws_vpc.vpc_wrench.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Tag exigida pelo AWS Load Balancer Controller para poder gerenciar as
  # regras deste security group (registro de targets em ip mode).
  tags = merge({
    Name                                           = var.projectName
    "kubernetes.io/cluster/eks-${var.projectName}" = "owned"
  }, var.main_tags)
}
