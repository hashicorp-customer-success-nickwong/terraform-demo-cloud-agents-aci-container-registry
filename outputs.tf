output "login_server" {
  value = azurerm_container_registry.demo.login_server
}

output "admin_username" {
  value = azurerm_container_registry.demo.admin_username
}

output "admin_password" {
  value     = azurerm_container_registry.demo.admin_password
  sensitive = true
}