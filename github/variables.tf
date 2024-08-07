variable "sanduba_admin_database_connection_string" {
  sensitive = true
  type      = string
  default   = ""
}

variable "sanduba_product_topic_manager_connection_string" {
  type      = string
  sensitive = true
  default   = ""
}

variable "sanduba_product_topic_publisher_connection_string" {
  type      = string
  sensitive = true
  default   = ""
}

variable "sanduba_product_topic_listener_connection_string" {
  type      = string
  sensitive = true
  default   = ""
}