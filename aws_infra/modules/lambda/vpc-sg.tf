resource "aws_security_group" "this" {
  count = var.vpc_subnet_ids != null ? 1 : 0

  name_prefix = "${var.name}-sg"
  description = "${var.name}-sg"

  vpc_id = var.vpc_id

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = var.vpc_subnet_ids != null ? var.vpc_security_group_egress : {}

  security_group_id = aws_security_group.this[0].id

  cidr_ipv4   = each.value.cidr_ipv4
  from_port   = each.value.from_port
  to_port     = each.value.to_port
  ip_protocol = each.value.ip_protocol
  description = each.value.description

  tags = var.tags
}
