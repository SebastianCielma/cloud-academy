variable "github_repo" {
  description = "GitHub Repository"
  type        = string
  default     = "sebastiancielma/cloud-academy" 
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

resource "aws_iam_role" "github_plan" {
  name = "GitHubActions-Plan-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = { StringLike = { "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*" } }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "plan_state_access" {
  name = "TerraformStateAccess"
  role = aws_iam_role.github_plan.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject", 
          "s3:ListBucket",
          "dynamodb:GetItem", 
          "dynamodb:PutItem", 
          "dynamodb:DeleteItem" 
        ]
        Resource = "*" 
      }
    ]
  })
}

resource "aws_iam_role" "github_apply" {
  name = "GitHubActions-Apply-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = { StringLike = { "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*" } }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "apply_admin" {
  role       = aws_iam_role.github_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "plan_role_arn" {
  value = aws_iam_role.github_plan.arn
}

output "apply_role_arn" {
  value = aws_iam_role.github_apply.arn
}