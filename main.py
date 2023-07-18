module "domains_testing" {
  source = "../opensearch/modules/opensearch"
  providers = {
    aws.owner = aws
    vault     = vault
  }

  for_each                  = { for domain in local.private_domain_input : domain.domain_name => domain }
  name                      = each.value.domain_name
  storage_volume_size       = each.value.storage_volume_size
  instance_type             = each.value.instance_type
  instance_count            = each.value.instance_count
  user_vault_path           = each.value.user_vault_path
  environment               = each.value.environment_name
  backup_enabled            = each.value.backup.enabled
  backup_bucket_name        = each.value.backup.bucket_name
  backup_retention_period   = each.value.backup.retention_period
  environment_name          = each.value.environment_name
  domain_name               = each.value.name
  public_facing             = lookup(each.value, "public_facing", false)
}
