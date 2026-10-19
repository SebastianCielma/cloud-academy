output "scenario_1_2_role_arn" {
  value = aws_iam_role.scenario_1_2_role.arn
}
output "scenario_1_2_bucket_name" {
  value = aws_s3_bucket.scenario_1_2_bucket.id
}
output "scenario_3_role_arn" {
  value = aws_iam_role.scenario_3_role.arn
}
output "scenario_3_bucket_name" {
  value = aws_s3_bucket.scenario_3_kms_bucket.id
}

output "scenario_4_caller_role_arn" {
  value = aws_iam_role.caller_role.arn
}
output "scenario_4_target_role_arn" {
  value = aws_iam_role.target_role.arn
}

output "scenario_5_role_arn" {
  value = aws_iam_role.scenario_5_role.arn
}
output "scenario_6_scp_json" {
  value = data.aws_iam_policy_document.scenario_6_scp.json
}

output "scenario_7_role_a_arn" {
  value = aws_iam_role.abac_role_a.arn
}
output "scenario_7_role_b_arn" {
  value = aws_iam_role.abac_role_b.arn
}
output "scenario_7_bucket" {
  value = aws_s3_bucket.abac_bucket.id
}

output "scenario_final_ecs_dev_role" {
  value = aws_iam_role.ecs_dev_role.arn
}
output "scenario_final_ecs_task_role" {
  value = aws_iam_role.ecs_task_role.arn
}