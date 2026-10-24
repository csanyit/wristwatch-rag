resource "aws_s3_bucket_notification" "this" {
  count       = var.file_system_compatible ? 1 : 0
  bucket      = aws_s3_bucket.content.id
  eventbridge = true # NOTE: It is mandatory to keep eventbridge enabled, to ensure S3 Files get notification of S3 changes
}
