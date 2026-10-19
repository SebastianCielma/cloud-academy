# ==============================================================================
# SCENARIO 4: CROSS-ACCOUNT MYSTERY (ROLE CHAINING FAIL)
# ==============================================================================

data "aws_iam_policy_document" "caller_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "caller_role" {
  name               = "scenario-4-caller-role"
  assume_role_policy = data.aws_iam_policy_document.caller_trust.json
}

data "aws_iam_policy_document" "caller_identity" {
  statement {
    sid       = "AllowAssumeTarget"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.target_role.arn]
  }
}

resource "aws_iam_role_policy" "caller_policy" {
  name   = "assume-target-policy"
  role   = aws_iam_role.caller_role.id
  policy = data.aws_iam_policy_document.caller_identity.json
}

data "aws_iam_policy_document" "target_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.caller_role.arn]
    }
  }
}

resource "aws_iam_role" "target_role" {
  name               = "scenario-4-target-role"
  assume_role_policy = data.aws_iam_policy_document.target_trust.json
}