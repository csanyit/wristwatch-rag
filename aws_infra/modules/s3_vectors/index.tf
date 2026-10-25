resource "aws_s3vectors_index" "this" {
  for_each = var.indexes

  index_name         = each.key
  vector_bucket_name = aws_s3vectors_vector_bucket.this.vector_bucket_name
  data_type          = each.value.data_type
  dimension          = each.value.dimension
  distance_metric    = each.value.distance_metric
  tags               = merge(var.tags, each.value.tags)

  dynamic "metadata_configuration" {
    for_each = length(each.value.non_filterable_metadata_keys) > 0 ? [each.value.non_filterable_metadata_keys] : []
    content {
      non_filterable_metadata_keys = metadata_configuration.value
    }
  }

  dynamic "encryption_configuration" {
    for_each = each.value.encryption == null ? [] : [each.value.encryption]
    content {
      sse_type    = encryption_configuration.value.sse_type
      kms_key_arn = encryption_configuration.value.kms_key_arn
    }
  }
}
