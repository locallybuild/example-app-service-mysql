variable "name_prefix" {
  description = "The prefix used for all resources in this example."
  type        = string
}

variable "location" {
  description = "The region where these resources should be deployed."
  type        = string
}

variable "tags" {
  description = "A mapping of tags which should be applied to each of the resources."
  type        = map(string)
  default     = {}
}

variable "app_service_sku" {
  description = "App Service plan SKU."
  type        = string
  default     = "B1"
}
