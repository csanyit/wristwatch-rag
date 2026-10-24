################################################################################
# Migrations: one lifecycle configuration per bucket
################################################################################

# The lifecycle configurations were created once per rule, each holding all rules. They are
# forgotten instead of destroyed: destroying one deletes the bucket's whole lifecycle
# configuration. The single replacement resource writes the same rules in the same apply.

removed {
  from = aws_s3_bucket_lifecycle_configuration.content

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_s3_bucket_lifecycle_configuration.access_log

  lifecycle {
    destroy = false
  }
}
