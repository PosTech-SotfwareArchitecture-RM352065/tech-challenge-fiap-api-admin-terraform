
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

data "azurerm_servicebus_topic_authorization_rule" "customer_topic_manager" {
  name     = "${data.azurerm_servicebus_topic.customer_topic.name}-manager"
  topic_id = data.azurerm_servicebus_topic.customer_topic.id
}

resource "azurerm_servicebus_subscription" "customer_topic_subscription" {
  name               = "customer-topic-admin-subscription"
  topic_id           = data.azurerm_servicebus_topic.customer_topic.id
  max_delivery_count = 1
}

resource "azurerm_servicebus_namespace" "servicebus_namespace" {
  name                = "fiap-tech-challenge-product-topic-namespace"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  sku                 = "Standard"

  tags = {
    environment = azurerm_resource_group.resource_group.tags["environment"]
  }
}

resource "azurerm_servicebus_topic" "servicebus_topic" {
  name         = "fiap-tech-challenge-product-topic"
  namespace_id = azurerm_servicebus_namespace.servicebus_namespace.id
}

resource "azurerm_servicebus_topic_authorization_rule" "servicebus_topic_manager" {
  name     = "${azurerm_servicebus_topic.servicebus_topic.name}-manager"
  topic_id = azurerm_servicebus_topic.servicebus_topic.id
  listen   = true
  send     = true
  manage   = true
}

resource "azurerm_servicebus_topic_authorization_rule" "servicebus_topic_publisher" {
  name     = "${azurerm_servicebus_topic.servicebus_topic.name}-publisher"
  topic_id = azurerm_servicebus_topic.servicebus_topic.id
  listen   = false
  send     = true
  manage   = false
}

resource "azurerm_servicebus_topic_authorization_rule" "servicebus_topic_listener" {
  name     = "${azurerm_servicebus_topic.servicebus_topic.name}-listener"
  topic_id = azurerm_servicebus_topic.servicebus_topic.id
  listen   = true
  send     = false
  manage   = false
}

data "azurerm_storage_account" "log_storage_account" {
  name                = "sandubalog"
  resource_group_name = var.main_resource_group
}

data "azurerm_log_analytics_workspace" "log_workspace" {
  name                = "fiap-tech-challenge-observability-workspace"
  resource_group_name = data.azurerm_storage_account.log_storage_account.resource_group_name
}

# resource "azurerm_monitor_diagnostic_setting" "topic_monitor" {
#   name                       = "fiap-tech-challenge-product-topic-monitor"
#   target_resource_id         = azurerm_servicebus_namespace.servicebus_namespace.id
#   storage_account_id         = data.azurerm_storage_account.log_storage_account.id
#   log_analytics_workspace_id = data.azurerm_log_analytics_workspace.log_workspace.id

#   enabled_log {
#     category_group = "allLogs"
#   }

#   metric {
#     category = "AllMetrics"
#   }
# }

resource "azurerm_container_app_environment" "container_app_environment" {
  name                       = "fiap-tech-challange-admin-app-environment"
  location                   = azurerm_resource_group.resource_group.location
  resource_group_name        = azurerm_resource_group.resource_group.name
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.log_workspace.id
}

resource "azurerm_container_app" "container_app" {
  name                         = "fiap-tech-challange-admin-app"
  container_app_environment_id = azurerm_container_app_environment.container_app_environment.id
  resource_group_name          = azurerm_container_app_environment.container_app_environment.resource_group_name
  revision_mode                = "Single"

  template {
    container {
      name   = "sanduba-admin-api"
      image  = "docker.io/cangelosilima/sanduba-admin-api:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      
      env {
        name  = "WEBSITES_ENABLE_APP_SERVICE_STORAGE"
        value = "false"
      }

      env {
        name  = "ASPNETCORE_ConnectionStrings__AdminDatabase__Type"
        value = "MSSQL"
      }

      env {
        name  = "ASPNETCORE_ConnectionStrings__AdminDatabase__Value"
        value = "Server=tcp:${azurerm_mssql_server.sqlserver.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.sanduba_admin_database.name};Persist Security Info=False;User ID=${random_uuid.sqlserver_user.result};Password=${random_password.sqlserver_password.result};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
      }

      env {
        name  = "ASPNETCORE_CustomerBrokerSettings__ConnectionStrings"
        value = data.azurerm_servicebus_topic_authorization_rule.customer_topic_manager.primary_connection_string
      }

      env {
        name  = "ASPNETCORE_CustomerBrokerSettings__TopicName"
        value = data.azurerm_servicebus_topic.customer_topic.name
      }

      env {
        name  = "ASPNETCORE_CustomerBrokerSettings__SubscriptionName"
        value = azurerm_servicebus_subscription.customer_topic_subscription.name
      }

      env {
        name  = "ASPNETCORE_ProductBrokerSettings__ConnectionStrings"
        value = azurerm_servicebus_topic_authorization_rule.servicebus_topic_manager.primary_connection_string
      }
    }
  }
  
    ingress {
      external_enabled = true    # Set to false if you want the ingress to be internal only
      target_port      = 8080      # The port that your container listens to
      transport        = "auto"  # Can be "http", "https", or "auto" for both
      traffic_weight {
        percentage      =  100
        latest_revision = true
      }
    }
}

output "sanduba_admin_url" {
  sensitive = false
  value     = "https://${azurerm_container_app.container_app.ingress[0].fqdn}"
}

output "sanduba_admin_database_connection_string" {
  sensitive = true
  value     = "Server=tcp:${azurerm_mssql_server.sqlserver.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.sanduba_admin_database.name};Persist Security Info=False;User ID=${random_uuid.sqlserver_user.result};Password=${random_password.sqlserver_password.result};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
}

output "sanduba_product_topic_manager_connection_string" {
  sensitive = true
  value     = azurerm_servicebus_topic_authorization_rule.servicebus_topic_manager.primary_connection_string
}

output "sanduba_product_topic_publisher_connection_string" {
  sensitive = true
  value     = azurerm_servicebus_topic_authorization_rule.servicebus_topic_publisher.primary_connection_string
}

output "sanduba_product_topic_listener_connection_string" {
  sensitive = true
  value     = azurerm_servicebus_topic_authorization_rule.servicebus_topic_listener.primary_connection_string
}