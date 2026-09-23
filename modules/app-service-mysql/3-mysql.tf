# ---------------------------------------------------------------------------
# Database - Azure Database for MySQL Flexible Server
#
# Stores the notes. The dbformysql plugin launches a real MySQL container in
# Docker/Podman to back this server.
#
# MySQL Flexible Server always requires an administrator login and password.
# The password is a generated random value that's never given to the app - the
# app signs in with its managed identity instead (see the Entra administrator
# below).
# ---------------------------------------------------------------------------
resource "random_password" "mysql_admin" {
  length           = 24
  special          = true
  override_special = "!#%*-_"
}

resource "azurerm_mysql_flexible_server" "main" {
  name                   = "${var.name_prefix}-mysql"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  administrator_login    = "mysqladmin"
  administrator_password = random_password.mysql_admin.result
  sku_name               = "B_Standard_B1ms"
  version                = "8.0.21"
  tags                   = var.tags

  storage {
    size_gb = 20
  }

  # The server needs an identity of its own to validate Entra tokens presented
  # by clients - this is required by the Entra administrator below.
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }
}

# ---------------------------------------------------------------------------
# Entra administrator - makes the managed identity an administrator of the
# server, so the app can sign in as it using an Entra access token as the
# password (the MySQL user name is the identity's name).
# ---------------------------------------------------------------------------
resource "azurerm_mysql_flexible_server_active_directory_administrator" "main" {
  server_id   = azurerm_mysql_flexible_server.main.id
  identity_id = azurerm_user_assigned_identity.main.id
  login       = azurerm_user_assigned_identity.main.name
  object_id   = azurerm_user_assigned_identity.main.principal_id
  tenant_id   = data.azurerm_client_config.current.tenant_id
}

resource "azurerm_mysql_flexible_database" "notes" {
  name                = "notes"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}
