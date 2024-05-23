output "key_vault_id" {
  value = azurerm_key_vault.customer.id
}
output "vault_uri" {
  value = azurerm_key_vault.customer.vault_uri
}

output "key_name" {
  value = azurerm_key_vault_key.saas_product1.name
}