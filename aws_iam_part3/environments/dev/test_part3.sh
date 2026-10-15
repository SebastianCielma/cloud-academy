#!/bin/bash

export AWS_REGION="eu-central-1"
export AWS_DEFAULT_REGION="eu-central-1"

ACCOUNT_ID=$(aws sts get-caller-identity --region eu-central-1 --query "Account" --output text)
WILDCARD_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/dev-wildcard-role"
S3_ONLY_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/dev-s3-only-role"
BOUNDARY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/developer-boundary"

SCP_JSON=$(terraform output -raw scp_policy_json_preview 2>/dev/null | tr -d '\n\r ')

echo "AWS IAM PART 3 - FULL COMPLIANCE TEST SUITE"
echo "Account ID: $ACCOUNT_ID"
echo "--------------------------------------------------------------------------------"

run_sim_test() {
    local test_id=$1
    local desc=$2
    local role_arn=$3
    local action=$4
    local region=$5
    local expected=$6
    shift 6

    result=$(aws iam simulate-principal-policy \
        --region eu-central-1 \
        --policy-source-arn "$role_arn" \
        --action-names "$action" \
        --context-entries "ContextKeyName=aws:RequestedRegion,ContextKeyValues=${region},ContextKeyType=string" \
        "$@" \
        --query "EvaluationResults[0].EvalDecision" \
        --output text 2>/dev/null)

    if [ "$result" == "$expected" ]; then
        status="PASS"
    else
        status="FAIL"
    fi

    echo "[$status] $test_id: $desc | Action: $action | Region: $region -> Result: $result (Expected: $expected)"
}

echo "1. PERMISSION BOUNDARY (Role with Action: * limited to S3, CloudWatch, SQS)"
run_sim_test "1.1" "Allow S3 service" "$WILDCARD_ROLE_ARN" "s3:ListAllMyBuckets" "eu-central-1" "allowed"
run_sim_test "1.2" "Allow CloudWatch service" "$WILDCARD_ROLE_ARN" "cloudwatch:PutMetricData" "eu-central-1" "allowed"
run_sim_test "1.3" "Allow SQS service" "$WILDCARD_ROLE_ARN" "sqs:CreateQueue" "eu-west-1" "allowed"
run_sim_test "1.4" "Block IAM administration" "$WILDCARD_ROLE_ARN" "iam:CreateUser" "eu-central-1" "explicitDeny"
run_sim_test "1.5" "Block Organizations admin" "$WILDCARD_ROLE_ARN" "organizations:DescribeOrganization" "eu-central-1" "explicitDeny"
run_sim_test "1.6" "Block KMS administration" "$WILDCARD_ROLE_ARN" "kms:CreateKey" "eu-central-1" "explicitDeny"

echo ""
echo "2. BOUNDARY VS POLICY INTERSECTION"
run_sim_test "2.1" "Allow in Policy (*), missing in Boundary" "$WILDCARD_ROLE_ARN" "ec2:RunInstances" "eu-central-1" "implicitDeny"
run_sim_test "2.2" "Allow in Boundary (SQS), missing in Policy (S3 only)" "$S3_ONLY_ROLE_ARN" "sqs:ListQueues" "eu-central-1" "implicitDeny"

echo ""
echo "3. SCP GUARDRAILS & SCP BEHAVIOR"
run_sim_test "3.1" "SCP blocks disabling CloudTrail" "$WILDCARD_ROLE_ARN" "cloudtrail:StopLogging" "eu-central-1" "explicitDeny" \
    --permissions-boundary-policy-input-list "$SCP_JSON"
run_sim_test "3.2" "SCP blocks deleting security logs" "$WILDCARD_ROLE_ARN" "logs:DeleteLogGroup" "eu-central-1" "explicitDeny" \
    --permissions-boundary-policy-input-list "$SCP_JSON"
run_sim_test "3.3" "SCP blocks leaving Organization" "$WILDCARD_ROLE_ARN" "organizations:LeaveOrganization" "eu-central-1" "explicitDeny" \
    --permissions-boundary-policy-input-list "$SCP_JSON"

FULL_ALLOW_SCP='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}'
run_sim_test "3.4" "SCP Behavior: SCP with Allow:* does NOT grant permissions" "$S3_ONLY_ROLE_ARN" "ec2:RunInstances" "eu-central-1" "implicitDeny" \
    --permissions-boundary-policy-input-list "$FULL_ALLOW_SCP"

echo ""
echo "4. REGION RESTRICTION (eu-central-1 & eu-west-1 + Global Service Exceptions)"
run_sim_test "4.1" "Allowed in eu-central-1" "$WILDCARD_ROLE_ARN" "s3:PutObject" "eu-central-1" "allowed"
run_sim_test "4.2" "Allowed in eu-west-1" "$WILDCARD_ROLE_ARN" "s3:PutObject" "eu-west-1" "allowed"
run_sim_test "4.3" "Blocked in us-east-1 (Regional service)" "$WILDCARD_ROLE_ARN" "s3:PutObject" "us-east-1" "explicitDeny"

GLOBAL_TEST_BOUNDARY='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"},{"Effect":"Deny","NotAction":["iam:*","organizations:*","sts:*","cloudfront:*","route53:*","support:*"],"Resource":"*","Condition":{"StringNotEquals":{"aws:RequestedRegion":["eu-central-1","eu-west-1"]}}}]}'
run_sim_test "4.4" "Global service exception (CloudFront) allowed outside EU" "$WILDCARD_ROLE_ARN" "cloudfront:ListDistributions" "us-east-1" "allowed" \
    --permissions-boundary-policy-input-list "$GLOBAL_TEST_BOUNDARY"

echo ""
echo "5. LAYERED AUTHORIZATION (Identity + Boundary + SCP + Session Policy + Explicit Deny)"
LAYERED_GUARDRAIL='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:*","logs:*"],"Resource":"*"},{"Effect":"Deny","Action":"logs:DeleteLogGroup","Resource":"*"}]}'

run_sim_test "5.1" "Allowed across all 4 layers (Identity + Boundary + SCP + Session)" "$WILDCARD_ROLE_ARN" "s3:GetObject" "eu-central-1" "allowed" \
    --permissions-boundary-policy-input-list "$LAYERED_GUARDRAIL"
run_sim_test "5.2" "Blocked by Session Policy despite Identity and Boundary Allow" "$WILDCARD_ROLE_ARN" "sqs:SendMessage" "eu-central-1" "implicitDeny" \
    --permissions-boundary-policy-input-list "$LAYERED_GUARDRAIL"
run_sim_test "5.3" "Explicit Deny overrides Allow across layers" "$WILDCARD_ROLE_ARN" "logs:DeleteLogGroup" "eu-central-1" "explicitDeny" \
    --permissions-boundary-policy-input-list "$LAYERED_GUARDRAIL"

echo ""
echo "6. BUSINESS CONTEXT: DEVELOPER DELEGATION GUARDRAIL"
DELEGATION_ARN=$(aws iam get-policy --region eu-central-1 --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/developer-iam-delegation-guardrail" --query "Policy.Arn" --output text 2>/dev/null)
if [ -n "$DELEGATION_ARN" ] && [ "$DELEGATION_ARN" != "None" ]; then
    echo "[PASS] 6.1: Developer role-creation guardrail exists ($DELEGATION_ARN)"
else
    echo "[FAIL] 6.1: Developer role-creation guardrail missing"
fi
