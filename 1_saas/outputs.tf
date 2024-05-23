output "saas_product1_client_id" {
  value = azuread_application_registration.saas_product1.client_id
}

output "storage_account_id" {
  value = azurerm_storage_account.saas.id
}

output "location" {
  value = azurerm_resource_group.saas.location
}

output "rg_name" {
  value = azurerm_resource_group.saas.name
}

# output "private_link_subnet_id" {
#   value = azurerm_subnet.private_links.id
# }

# output "privatelink_vaultcore_azure_net_id" {
#   value = azurerm_private_dns_zone.keyvault.id
# }

output "user_assigned_identity_id" {
  value = azurerm_user_assigned_identity.storage_account.id
}

output "client_id" {
  value = azuread_application_registration.saas_product1.client_id
}

output "client_secret" {
  value     = azuread_application_password.terraform.value
  sensitive = true
}