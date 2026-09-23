# ---------------------------------------------------------------------------
# Container Registry - for storing the Container Image within Locally.
#
# App Service pulls the application image from here, the same as you'd host a
# private image on Azure.
# ---------------------------------------------------------------------------
resource "azurerm_container_registry" "main" {
  name                = "${replace(var.name_prefix, "-", "")}acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Build the application in ../../app and push it into the Locally ACR.
#
# The image is built for the host architecture: Locally runs the container on
# this same machine, so no cross-architecture build is needed. To deploy to
# Azure App Service instead, build and push a linux/amd64 (or multi-arch) image,
# e.g. with `docker buildx build --platform linux/amd64`.
# ---------------------------------------------------------------------------
resource "terraform_data" "build_and_push" {
  triggers_replace = [
    azurerm_container_registry.main.login_server,
    local.image_tag,
  ]

  provisioner "local-exec" {
    # The registry password is passed on stdin (--password-stdin) via an env var
    # rather than as a -p argument, so it never appears in the process list.
    environment = {
      REGISTRY_PASSWORD = azurerm_container_registry.main.admin_password
    }
    command = <<-EOT
      set -eu
      printf '%s' "$REGISTRY_PASSWORD" | docker login ${azurerm_container_registry.main.login_server} -u ${azurerm_container_registry.main.admin_username} --password-stdin
      docker build -t ${azurerm_container_registry.main.login_server}/${local.image_name}:${local.image_tag} ${path.module}/../../app
      docker push ${azurerm_container_registry.main.login_server}/${local.image_name}:${local.image_tag}
    EOT
  }
}
