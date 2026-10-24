output "content_bucket" {
  description = "This S3 bucket."
  value       = aws_s3_bucket.content
}

output "bucket_policies" {
  description = "Access control information including policy statements and ARNs"
  value = {
    read_only_policy_statements  = local.read_only_policy_statements
    read_write_policy_statements = local.read_write_policy_statements
    read_only_policy_arn         = try(aws_iam_policy.read_only[0].arn, null)
    read_write_policy_arn        = try(aws_iam_policy.read_write[0].arn, null)
  }
}
