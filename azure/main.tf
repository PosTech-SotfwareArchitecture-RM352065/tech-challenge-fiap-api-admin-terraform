
resource "azurerm_resource_group" "resource_group" {
  name     = "fiap-tech-challenge-admin-group"
  location = var.main_resource_group_location

  tags = {
    environment = var.environment
  }
}

resource "random_password" "sqlserver_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_uuid" "sqlserver_user" {
}

resource "random_uuid" "auth_secret_key" {
}

resource "azurerm_mssql_server" "sqlserver" {
  name                         = "sanduba-admin-database"
  resource_group_name          = azurerm_resource_group.resource_group.name
  location                     = azurerm_resource_group.resource_group.location
  version                      = "12.0"
  administrator_login          = random_uuid.sqlserver_user.result
  administrator_login_password = random_password.sqlserver_password.result

  tags = {
    environment = azurerm_resource_group.resource_group.tags["environment"]
  }
}

resource "azurerm_mssql_firewall_rule" "sqlserver_allow_azure_services_rule" {
  name             = "Allow access to Azure services"
  server_id        = azurerm_mssql_server.sqlserver.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_firewall_rule" "sqlserver_allow_home_ip_rule" {
  name             = "Allow access to Home IP"
  server_id        = azurerm_mssql_server.sqlserver.id
  start_ip_address = var.home_ip_address
  end_ip_address   = var.home_ip_address
}

resource "azurerm_mssql_database" "sanduba_admin_database" {
  name                 = "sanduba-admin-database"
  server_id            = azurerm_mssql_server.sqlserver.id
  collation            = "SQL_Latin1_General_CP1_CI_AS"
  sku_name             = "Basic"
  max_size_gb          = 2
  read_scale           = false
  zone_redundant       = false
  geo_backup_enabled   = false
  create_mode          = "Default"
  storage_account_type = "Local"

  tags = {
    environment = azurerm_resource_group.resource_group.tags["environment"]
  }
}

data "azurerm_servicebus_namespace" "customer_topic_namespace" {
  name                = "fiap-tech-challenge-customer-topic-namespace"
  resource_group_name = "fiap-tech-challenge-customer-group"
}

data "azurerm_servicebus_topic" "customer_topic" {
  name         = "fiap-tech-challenge-customer-topic"
  namespace_id = data.azurerm_servicebus_namespace.customer_topic_namespace.id
}

resource "azurerm_servicebus_subscription" "customer_topic_subscription" {
  name               = "customer-topic-admin-subscription"
  topic_id           = data.azurerm_servicebus_topic.customer_topic.id
  max_delivery_count = 1
}

output "sanduba_admin_database_connection_string" {
  sensitive = true
  value     = "Server=tcp:${azurerm_mssql_server.sqlserver.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.sanduba_admin_database.name};Persist Security Info=False;User ID=${random_uuid.sqlserver_user.result};Password=${random_password.sqlserver_password.result};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
}