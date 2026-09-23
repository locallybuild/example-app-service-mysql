# ---------------------------------------------------------------------------
# User-Assigned Managed Identity - the identity the app signs in to MySQL as.
#
# It's attached to both the web app (to fetch Entra tokens) and the MySQL server
# (which needs a server-side identity to validate those tokens). A user-assigned
# identity exists independently of either, so it can be made the server's Entra
# administrator before the web app is created.
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "main" {
  name                = "${var.name_prefix}-id"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}

# The tenant the identity lives in, required by the MySQL Entra administrator.
data "azurerm_client_config" "current" {}
