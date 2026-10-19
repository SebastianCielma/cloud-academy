# ==============================================================================
# SCENARIO FINAL: ECS & PASSROLE MYSTERY
# ==============================================================================

data "aws_iam_policy_document" "ecs_task_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "scenario-final-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_trust.json
}

data "aws_iam_policy_document" "ecs_dev_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "ecs_dev_role" {
  name               = "scenario-final-ecs-dev-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_dev_trust.json
}

data "aws_iam_policy_document" "ecs_dev_policy" {
  statement {
    sid       = "AllowECS"
    effect    = "Allow"
    actions   = [
      "ecs:RegisterTaskDefinition",
      "ecs:RunTask"
    ]
    resources = ["*"]
  }
  
   statement {
     effect = "Allow"
     actions = ["iam:PassRole"]
     resources = [aws_iam_role.ecs_task_role.arn]
   }
}

resource "aws_iam_role_policy" "ecs_dev_policy_attach" {
  name   = "ecs-developer-policy"
  role   = aws_iam_role.ecs_dev_role.id
  policy = data.aws_iam_policy_document.ecs_dev_policy.json
}