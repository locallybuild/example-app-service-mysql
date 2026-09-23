terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "app-service-mysql" {
  source = "../../modules/app-service-mysql"

  name_prefix = "locally-example-mysql"
  location    = "berlin"
  tags = {
    ProvisionedVia = "Terraform"
  }
}
