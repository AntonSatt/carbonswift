# IAM Role for EC2 instances with Bedrock permissions
resource "aws_iam_role" "carbon_shift" {
  name               = "carbon-shift-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "carbon-shift-ec2-role"
    Project = "CarbonShift"
  }
}

# IAM Policy for Amazon Bedrock access
resource "aws_iam_role_policy" "bedrock_access" {
  name = "bedrock-invoke-model"
  role = aws_iam_role.carbon_shift.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/anthropic.claude-*",
          "arn:aws:bedrock:*::foundation-model/amazon.titan-*"
        ]
      }
    ]
  })
}

# IAM Policy for CloudWatch Logs (optional, for debugging)
resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "cloudwatch-logs-access"
  role = aws_iam_role.carbon_shift.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/ec2/carbon-shift*"
      }
    ]
  })
}

# IAM Policy for EC2 instance metadata (for querying instance details)
resource "aws_iam_role_policy" "ec2_describe" {
  name = "ec2-describe-access"
  role = aws_iam_role.carbon_shift.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "carbon_shift" {
  name = "carbon-shift-instance-profile"
  role = aws_iam_role.carbon_shift.name

  tags = {
    Name    = "carbon-shift-instance-profile"
    Project = "CarbonShift"
  }
}
