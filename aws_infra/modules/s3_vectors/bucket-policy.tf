resource "aws_s3vectors_vector_bucket_policy" "this" {
  count = var.bucket_policy == null ? 0 : 1

  vector_bucket_arn = aws_s3vectors_vector_bucket.this.vector_bucket_arn
  policy            = var.bucket_policy
}
