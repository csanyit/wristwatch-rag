output "lambda_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.this.function_name
}

output "lambda_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "lambda_role_name" {
  description = "Lambda IAM role name"
  value       = aws_iam_role.lambda.name
}

output "lambda_role_arn" {
  description = "Lambda IAM role ARN"
  value       = aws_iam_role.lambda.arn
}

output "lambda_security_group_id" {
  description = "Id of the security group assigned to this Lambda function"
  value       = try(aws_security_group.this[0].id, null)
}
