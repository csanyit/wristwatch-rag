output "vector_bucket_name" {
  description = "Name of the S3 Vectors bucket."
  value       = aws_s3vectors_vector_bucket.this.vector_bucket_name
}

output "vector_bucket_arn" {
  description = "ARN of the S3 Vectors bucket."
  value       = aws_s3vectors_vector_bucket.this.vector_bucket_arn
}

output "bucket_policies" {
  description = "Read-only and read-write vector IAM policies and their ARNs."
  value = {
    read_only_policy_statements  = data.aws_iam_policy_document.read_only.statement
    read_write_policy_statements = data.aws_iam_policy_document.read_write.statement
    read_only_policy_arn         = try(aws_iam_policy.read_only[0].arn, null)
    read_write_policy_arn        = try(aws_iam_policy.read_write[0].arn, null)
  }
}


output "vector_index_arns" {
  description = "ARNs of the vector indexes created in this bucket."
  value       = { for name, index in aws_s3vectors_index.this : name => index.index_arn }
}