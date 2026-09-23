# ---------------------------------------------------------------------------
# App Service Plan - houses the App Service running the custom container.
# ---------------------------------------------------------------------------
resource "azurerm_service_plan" "main" {
  name                = "${var.name_prefix}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_service_sku
}

# ---------------------------------------------------------------------------
# Linux App Service (Web App for Containers) - runs the Notes app.
#
# The image is pulled from the Locally Container Registry it was pushed into.
# App Service terminates TLS at the platform, so the browser reaches the app
# over HTTPS while the container serves plain HTTP on WEBSITES_PORT.
# ---------------------------------------------------------------------------
resource "azurerm_linux_web_app" "main" {
  name                = local.web_app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true
  tags                = var.tags

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  # The same identity that's the MySQL server's Entra administrator. The app
  # uses it to fetch the access token it signs in to MySQL with.
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }

  site_config {
    health_check_path                 = "/healthz"
    health_check_eviction_time_in_min = 2

    application_stack {
      docker_image_name        = "${local.image_name}:${local.image_tag}"
      docker_registry_url      = "https://${azurerm_container_registry.main.login_server}"
      docker_registry_username = azurerm_container_registry.main.admin_username
      docker_registry_password = azurerm_container_registry.main.admin_password
    }
  }

  app_settings = {
    # App Service routes public traffic to the container on this port, and the
    # app binds to it (12-factor port binding).
    WEBSITES_PORT = tostring(local.app_port)
    PORT          = tostring(local.app_port)

    # Where and as whom to connect. There's no password: the app presents an
    # Entra access token for the managed identity instead.
    MYSQL_HOST     = local.mysql_host
    MYSQL_PORT     = local.mysql_port
    MYSQL_DATABASE = azurerm_mysql_flexible_database.notes.name
    MYSQL_USER     = azurerm_user_assigned_identity.main.name

    # Selects the user-assigned identity for DefaultAzureCredential.
    AZURE_CLIENT_ID = azurerm_user_assigned_identity.main.client_id
  }

  depends_on = [
    # The image must exist in the registry before the App Service starts pulling it.
    terraform_data.build_and_push,

    # The identity must be the server's Entra administrator before the app
    # first signs in.
    azurerm_mysql_flexible_server_active_directory_administrator.main,
  ]
}
