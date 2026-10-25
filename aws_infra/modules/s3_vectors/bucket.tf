resource "aws_s3vectors_vector_bucket" "this" {
  vector_bucket_name = var.name
  force_destroy      = var.force_destroy
  tags               = var.tags

  encryption_configuration {
    sse_type    = var.encryption.sse_type
    kms_key_arn = var.encryption.kms_key_arn
  }
}
