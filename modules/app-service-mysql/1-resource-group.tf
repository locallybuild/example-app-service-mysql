# ---------------------------------------------------------------------------
# Resource Group - which contains the deployed resources
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "${var.name_prefix}-resources"
  location = var.location
  tags     = var.tags
}
