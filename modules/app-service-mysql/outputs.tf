output "application_url" {
  description = "Where to reach the application in a browser."
  value       = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "resource_group" {
  description = "The resource group containing the deployed resources."
  value       = azurerm_resource_group.main.name
}

output "mysql_fqdn" {
  description = "The fully qualified domain name of the MySQL server the application connects to."
  value       = azurerm_mysql_flexible_server.main.fqdn
}
