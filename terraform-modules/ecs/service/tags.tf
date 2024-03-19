locals {
  external_tags = var.tags
  tags = {
  for k, v in local.external_tags : k => v if lookup(data.aws_default_tags.default_tags.tags, k, null) == null || lookup(data.aws_default_tags.default_tags.tags, k, null) != v
  }
}
data "aws_default_tags" "default_tags" {}
