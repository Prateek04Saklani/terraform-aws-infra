# ── VPC ───────────────────────────────────────────────────────────────────────

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.app}-${var.env}-vpc"
  }
}

# ── Subnets ───────────────────────────────────────────────────────────────────

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id               = aws_vpc.this.id
  cidr_block           = each.value.cidr
  availability_zone_id = each.value.az

  tags = {
    Name = "private-subnet-${each.key}-${var.app}-${var.env}"
  }
}

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id               = aws_vpc.this.id
  cidr_block           = each.value.cidr
  availability_zone_id = each.value.az

  tags = {
    Name = "public-subnet-${each.key}-${var.app}-${var.env}"
  }
}

resource "aws_subnet" "db" {
  for_each = var.db_subnets

  vpc_id               = aws_vpc.this.id
  cidr_block           = each.value.cidr
  availability_zone_id = each.value.az

  tags = {
    Name = "db-subnet-${each.key}-${var.app}-${var.env}"
  }
}

# ── Internet gateway ──────────────────────────────────────────────────────────

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "igw-${var.app}-${var.env}"
  }
}

# ── NAT gateway ───────────────────────────────────────────────────────────────

resource "aws_eip" "nat" {
  domain = "vpc"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[keys(aws_subnet.public)[0]].id

  tags = {
    Name = "natgateway-${var.app}-${var.env}"
  }

  depends_on = [aws_internet_gateway.this]
}

# ── Route tables ──────────────────────────────────────────────────────────────

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "public-${var.app}-${var.env}-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "private-${var.app}-${var.env}-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db" {
  for_each = aws_subnet.db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# ── VPC flow logs ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = var.log_group
  retention_in_days = var.flow_log_retention_days

  tags = {
    Name = var.log_group
  }
}

data "aws_iam_policy_document" "flow_logs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = var.flow_logs_role_name
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_role.json
}

data "aws_iam_policy_document" "flow_logs_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "${var.app}-${var.env}-vpc-flow-logs-policy"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs_policy.json
}

resource "aws_flow_log" "this" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.this.id
}
