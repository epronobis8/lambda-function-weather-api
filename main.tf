provider "aws" {
  region = var.region
}

# VPC

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "${var.project}-vpc"
  }
}

# Public subnet

resource "aws_subnet" "subnet_public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet_public_cidr_block
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project}-subnet-public"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.project}-internet-gateway"
  }
}

resource "aws_route_table" "route_table_public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "${var.project}-route-table-public"
  }
}

resource "aws_route_table_association" "route_table_association_public" {
  subnet_id      = aws_subnet.subnet_public.id
  route_table_id = aws_route_table.route_table_public.id
}

resource "aws_eip" "eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.internet_gateway]
  tags = {
    Name = "${var.project}-eip"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.subnet_public.id

  tags = {
    Name = "${var.project}-nat-gateway"
  }
}

# Private subnet

resource "aws_subnet" "subnet_private" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet_private_cidr_block
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.project}-subnet-private"
  }
}

resource "aws_route_table" "route_table_private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "${var.project}-route-table-private"
  }
}

resource "aws_route_table_association" "route_table_association_private" {
  subnet_id      = aws_subnet.subnet_private.id
  route_table_id = aws_route_table.route_table_private.id
}

# Security

resource "aws_default_network_acl" "default_network_acl" {
  default_network_acl_id = aws_vpc.vpc.default_network_acl_id
  subnet_ids             = [aws_subnet.subnet_public.id, aws_subnet.subnet_private.id]

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${var.project}-default-network-acl"
  }
}

resource "aws_default_security_group" "default_security_group" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol    = -1
    self        = true
    from_port   = 0
    to_port     = 0
    cidr_blocks = [var.ip]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    #cidr_blocks = ["127.0.0.1/32"]
  }

  tags = {
    Name = "${var.project}-default-security-group"
  }
}

# Lambda

data "aws_iam_policy_document" "AWSLambdaTrustPolicy" {
  version = "2012-10-17"
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "iam_role" {
  assume_role_policy = data.aws_iam_policy_document.AWSLambdaTrustPolicy.json
  name               = "${var.project}-iam-role-lambda-trigger"
}

resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment_lambda_basic_execution" {
  role       = aws_iam_role.iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment_lambda_vpc_access_execution" {
  role       = aws_iam_role.iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment_lambda_vpc_ssm_read_access" {
  role       = aws_iam_role.iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_lambda_function" "lambda_function" {

  filename      = "${path.module}/privatelam/lambda.zip"
  function_name = "${var.project}-lambda-function-vpc-deployment"
  role          = aws_iam_role.iam_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  vpc_config {
    subnet_ids         = [aws_subnet.subnet_public.id, aws_subnet.subnet_private.id]
    security_group_ids = [aws_default_security_group.default_security_group.id]
  }
}

resource "aws_lambda_function" "lambda" {
  function_name = "lambda_function-non-vpc-deployment"
  filename      = "${path.module}/publiclam/lambda.zip"
  role          = aws_iam_role.iam_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
}

#Enable CW logging for Lambda
resource "aws_cloudwatch_log_group" "lambda-logs" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "lambda-logs2" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_function.function_name}"
  retention_in_days = 30
}

resource "aws_ssm_parameter" "api_key" {
  name  = "weather-api-key"
  type  = "String"
  value = var.api-key
}

resource "aws_cloudwatch_event_rule" "lambda_event_rule" {
  name                = "lambda-event-rule"
  description         = "retry scheduled every 5 min"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  arn  = aws_lambda_function.lambda.arn
  rule = aws_cloudwatch_event_rule.lambda_event_rule.name
}

resource "aws_cloudwatch_event_target" "lambda_target2" {
  arn  = aws_lambda_function.lambda_function.arn
  rule = aws_cloudwatch_event_rule.lambda_event_rule.name
}

resource "aws_lambda_permission" "invoke_fun" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_event_rule.arn
}

resource "aws_lambda_permission" "invoke_fun2" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_event_rule.arn
}