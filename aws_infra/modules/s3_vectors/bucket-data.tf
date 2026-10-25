data "aws_iam_policy_document" "read_only" {
  statement {
    sid    = "ReadVectorBucket"
    effect = "Allow"
    actions = [
      "s3vectors:GetVectorBucket",
      "s3vectors:ListIndexes",
    ]
    resources = [aws_s3vectors_vector_bucket.this.vector_bucket_arn]
  }

  statement {
    sid    = "ReadVectorIndexes"
    effect = "Allow"
    actions = [
      "s3vectors:GetIndex",
      "s3vectors:GetVectors",
      "s3vectors:ListVectors",
      "s3vectors:QueryVectors",
    ]
    resources = ["${aws_s3vectors_vector_bucket.this.vector_bucket_arn}/index/*"]
  }
}

data "aws_iam_policy_document" "read_write" {
  source_policy_documents = [data.aws_iam_policy_document.read_only.json]

  statement {
    sid    = "ManageVectorIndexes"
    effect = "Allow"
    actions = [
      "s3vectors:CreateIndex",
    ]
    resources = [aws_s3vectors_vector_bucket.this.vector_bucket_arn]
  }

  statement {
    sid    = "WriteVectorsAndManageIndexes"
    effect = "Allow"
    actions = [
      "s3vectors:DeleteIndex",
      "s3vectors:DeleteVectors",
      "s3vectors:PutVectors",
    ]
    resources = ["${aws_s3vectors_vector_bucket.this.vector_bucket_arn}/index/*"]
  }
}
