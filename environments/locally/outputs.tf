output "application_url" {
  description = "Where to reach the application in a browser."
  value       = module.app-service-mysql.application_url
}

output "mysql_fqdn" {
  description = "The fully qualified domain name of the MySQL server the application connects to."
  value       = module.app-service-mysql.mysql_fqdn
}
