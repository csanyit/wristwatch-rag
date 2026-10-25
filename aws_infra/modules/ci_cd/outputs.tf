output "role_name" {
  description = "Name of the CI/CD IAM role."
  value       = aws_iam_role.cicd_pipeline.name
}

output "role_arn" {
  description = "ARN of the CI/CD IAM role."
  value       = aws_iam_role.cicd_pipeline.arn
}

output "policy_arn" {
  description = "ARN of the policy attached to the CI/CD role."
  value       = aws_iam_policy.cicd_pipeline.arn
}

output "permissions_boundary_arn" {
  description = "ARN of the CI/CD role permissions boundary."
  value       = aws_iam_policy.cicd_pipeline_boundary.arn
}
