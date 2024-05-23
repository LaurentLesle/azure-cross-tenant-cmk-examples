provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

}

data "azurerm_client_config" "current" {}

# Get access to the keyvault and storage encryption key
data "terraform_remote_state" "saas" {
  backend = "local"

  config = {
    path = "../1_saas/terraform.tfstate"
  }
}

data "terraform_remote_state" "customer" {
  backend = "local"

  config = {
    path = "../2_customer/terraform.tfstate"
  }
}

# # Create the private endpoint to the customer keyvault
# resource "azurerm_private_endpoint" "customer_keyvault" {
#   name                = "customer-keyvault"
#   location            = data.terraform_remote_state.saas.outputs.location
#   resource_group_name = data.terraform_remote_state.saas.outputs.rg_name
#   subnet_id           = data.terraform_remote_state.saas.outputs.private_link_subnet_id

#   private_service_connection {
#     name                           = "customer-keyvault"
#     private_connection_resource_id = data.terraform_remote_state.customer.outputs.key_vault_id
#     subresource_names              = ["vault"]
#     is_manual_connection           = true
#     request_message = "SaaS product 1 requesting access to customer keyvault"
#   }

#   private_dns_zone_group {
#     name                 = "customer-keyvault"
#     private_dns_zone_ids = [data.terraform_remote_state.saas.outputs.privatelink_vaultcore_azure_net_id]
#   }
# }

resource "azurerm_storage_account_customer_managed_key" "customer" {
  storage_account_id           = data.terraform_remote_state.saas.outputs.storage_account_id
  key_vault_uri                = data.terraform_remote_state.customer.outputs.vault_uri
  key_name                     = data.terraform_remote_state.customer.outputs.key_name
  user_assigned_identity_id    = data.terraform_remote_state.saas.outputs.user_assigned_identity_id
  federated_identity_client_id = data.terraform_remote_state.saas.outputs.saas_product1_client_id

}