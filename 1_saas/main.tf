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
resource "azurerm_resource_group" "saas" {
  name     = "rg-saas-product1"
  location = "eastasia"
}

#
# Create a virtual network
#

resource "azurerm_virtual_network" "saas" {
  name                = "saas-network"
  location            = azurerm_resource_group.saas.location
  resource_group_name = azurerm_resource_group.saas.name
  address_space       = ["10.0.0.0/16"]
}

# #
# # Private DNS zones 
# #

# resource "azurerm_private_dns_zone" "keyvault" {
#   name                = "privatelink.vaultcore.azure.net"
#   resource_group_name = azurerm_resource_group.saas.name
# }

# # Link the private DNS zone to the virtual network
# resource "azurerm_private_dns_zone_virtual_network_link" "saas" {
#   name                  = "keyvault"
#   resource_group_name   = azurerm_resource_group.saas.name
#   private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
#   virtual_network_id    = azurerm_virtual_network.saas.id
# }

# # subnet to host the private endpoints
# resource "azurerm_subnet" "private_links" {
#   name                 = "plinks"
#   resource_group_name  = azurerm_resource_group.saas.name
#   virtual_network_name = azurerm_virtual_network.saas.name
#   address_prefixes     = ["10.0.1.0/24"]

#   private_endpoint_network_policies = "Disabled"
# }

# Create the app registration that will be used by saass
resource "azuread_application_registration" "saas_product1" {
  display_name     = "msi-saas-product1"
  description      = "Application used by SaaS product 1"
  sign_in_audience = "AzureADMultipleOrgs"
}

resource "azurerm_user_assigned_identity" "storage_account" {
  location            = azurerm_resource_group.saas.location
  name                = "msi-storage-account"
  resource_group_name = azurerm_resource_group.saas.name
}

resource "azuread_application_federated_identity_credential" "saas_product1" {
  application_id = azuread_application_registration.saas_product1.id
  display_name   = "storage_account"
  description    = "Credential to access saas product1 storage account"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = format("https://login.microsoftonline.com/%s/v2.0", data.azurerm_client_config.current.tenant_id)
  subject        = azurerm_user_assigned_identity.storage_account.principal_id
}

resource "azuread_application_password" "terraform" {
  application_id = azuread_application_registration.saas_product1.id
}

resource "azurerm_storage_account" "saas" {
  name                = "stgsaas342434324231"
  resource_group_name = azurerm_resource_group.saas.name

  location                 = azurerm_resource_group.saas.location
  account_tier             = "Premium"   # Required for CMK
  account_kind             = "StorageV2" # Required for CMK
  account_replication_type = "LRS"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage_account.id] # Required for CMK
  }

  network_rules {
    default_action = "Deny"
  }

  lifecycle {
    ignore_changes = [ customer_managed_key ]
  }
}


resource "azurerm_log_analytics_workspace" "saas" {
  name                = "kvlogs34556546754234"
  location            = azurerm_resource_group.saas.location
  resource_group_name = azurerm_resource_group.saas.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

data "azurerm_monitor_diagnostic_categories" "azurerm_storage_account" {
  resource_id = azurerm_storage_account.saas.id
}

resource "azurerm_monitor_diagnostic_setting" "azurerm_storage_account" {
  name                       = "logs"
  target_resource_id         = azurerm_storage_account.saas.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.saas.id

  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.azurerm_storage_account.log_category_groups

    content {
      category_group = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = data.azurerm_monitor_diagnostic_categories.azurerm_storage_account.metrics

    content {
      category = metric.value
      enabled = true
    }
  }

}


# Sto
data "azurerm_monitor_diagnostic_categories" "azurerm_storage_account_blob" {
  resource_id = format("%s/blobServices/default", azurerm_storage_account.saas.id)
}

resource "azurerm_monitor_diagnostic_setting" "azurerm_storage_account_blob" {
  name                       = "logs"
  target_resource_id         = format("%s/blobServices/default", azurerm_storage_account.saas.id)
  log_analytics_workspace_id = azurerm_log_analytics_workspace.saas.id

  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.azurerm_storage_account_blob.log_category_groups

    content {
      category_group = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = data.azurerm_monitor_diagnostic_categories.azurerm_storage_account_blob.metrics

    content {
      category = metric.value
      enabled = true
    }
  }

}