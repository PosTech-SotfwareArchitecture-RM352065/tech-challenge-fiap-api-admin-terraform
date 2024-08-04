variable "location" {
  type      = string
  sensitive = false
  default   = ""
}

variable "environment" {
  type      = string
  sensitive = false
  default   = ""
}

variable "home_ip_address" {
  type      = string
  sensitive = true
  default   = ""
}