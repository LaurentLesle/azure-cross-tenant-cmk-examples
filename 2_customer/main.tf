provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

data "azurerm_client_config" "current" {}

#
# Create a resource group
#
resource "azurerm_resource_group" "customer" {
  name     = "rg-keyvault"
  location = "southeastasia"
}

#
# Create a virtual network
#

resource "azurerm_virtual_network" "customer" {
  name                = "customer-network"
  location            = azurerm_resource_group.customer.location
  resource_group_name = azurerm_resource_group.customer.name
  address_space       = ["10.0.0.0/16"]
}

#
# Private DNS zones 
#

resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.customer.name
}

# Link the private DNS zone to the virtual network
resource "azurerm_private_dns_zone_virtual_network_link" "customer" {
  name                  = "keyvault"
  resource_group_name   = azurerm_resource_group.customer.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.customer.id
}

# subnet to host the private endpoints
resource "azurerm_subnet" "private_links" {
  name                 = "plinks"
  resource_group_name  = azurerm_resource_group.customer.name
  virtual_network_name = azurerm_virtual_network.customer.name
  address_prefixes     = ["10.0.1.0/24"]

  private_endpoint_network_policies = "Disabled"
}

# # Private Link services
# resource "azurerm_subnet" "private_link_service" {
#   name                 = "plinks-service"
#   resource_group_name  = azurerm_resource_group.customer.name
#   virtual_network_name = azurerm_virtual_network.customer.name
#   address_prefixes     = ["10.0.2.0/24"]

#   private_link_service_network_policies_enabled = false
# }

# Keyvault to host the secrets, keys and certificates
resource "azurerm_key_vault" "customer" {
  name                      = "cxkv213213dwq"
  location                  = azurerm_resource_group.customer.location
  resource_group_name       = azurerm_resource_group.customer.name
  enable_rbac_authorization = true
  # public_network_access_enabled = false
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
  sku_name                   = "premium"

  network_acls {
    bypass         = "AzureServices" # Allow the SaaS storage CMK to access the storage encryption key.
    default_action = "Deny"
    ip_rules       = var.ip_rules
  }
}

# Grant admin privileges to the current user
resource "azurerm_role_assignment" "current_user_keyvault_contributor" {
  scope                = azurerm_key_vault.customer.id
  role_definition_name = "Key Vault Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
resource "azurerm_role_assignment" "current_user_keyvault_crypto_officer" {
  scope                = azurerm_key_vault.customer.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Create a storage encryption key in the keyvault
resource "azurerm_key_vault_key" "saas_product1" {
  name         = "saas-product1-stg"
  key_vault_id = azurerm_key_vault.customer.id
  key_type     = "RSA-HSM"
  key_size     = 4096
  key_opts = toset(
    [
      "decrypt",
      "encrypt",
      "sign",
      "unwrapKey",
      "verify",
      "wrapKey"
    ]
  )

  depends_on = [
    azurerm_role_assignment.current_user_keyvault_crypto_officer
  ]
}

resource "azurerm_log_analytics_workspace" "customer" {
  name                = "kvlogs345324234"
  location            = azurerm_resource_group.customer.location
  resource_group_name = azurerm_resource_group.customer.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

data "azurerm_monitor_diagnostic_categories" "customer" {
  resource_id = azurerm_log_analytics_workspace.customer.id
}

resource "azurerm_monitor_diagnostic_setting" "customer" {
  name                       = "logs"
  target_resource_id         = azurerm_key_vault.customer.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.customer.id

  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.customer.log_category_groups

    content {
      category_group = enabled_log.value
    }
  }

  metric {
    category = "AllMetrics"
    enabled  = false
  }

  depends_on = [data.azurerm_monitor_diagnostic_categories.customer]
}

# To be accessed by customer
resource "azurerm_private_endpoint" "keyvault" {
  name                = "customer-keyvault"
  location            = azurerm_resource_group.customer.location
  resource_group_name = azurerm_resource_group.customer.name
  subnet_id           = azurerm_subnet.private_links.id

  private_service_connection {
    name                           = "customer-privateserviceconnection"
    private_connection_resource_id = azurerm_key_vault.customer.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "customer-keyvault"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
  }
}


# Create an enterprise application (service principal) from the SAAS product 1 client_id
data "terraform_remote_state" "saas" {
  backend = "local"

  config = {
    path = "../1_saas/terraform.tfstate"
  }
}

resource "azuread_service_principal" "sp_saas_product1" {
  client_id = data.terraform_remote_state.saas.outputs.saas_product1_client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

# Assign the enterprise application to the keyvault
resource "azurerm_role_assignment" "sp_saas_product1_crypto_service_encryption_user" {
  scope                = azurerm_key_vault.customer.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azuread_service_principal.sp_saas_product1.id
}