resource "github_actions_organization_secret" "sanduba_admin_database_connectionstring" {
  secret_name     = "APP_ADMIN_DATABASE_CONNECTION_STRING"
  visibility      = "all"
  plaintext_value = var.sanduba_admin_database_connection_string
}
