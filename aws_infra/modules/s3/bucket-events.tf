resource "aws_s3_bucket_notification" "this" {
  bucket      = aws_s3_bucket.content.id
  eventbridge = true # NOTE: It is mandatory to keep eventbridge enabled, to ensure S3 Files get notification of S3 changes

  lifecycle {
    enabled = var.file_system_compatible
  }
}
