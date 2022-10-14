terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    github = {
      source = "integrations/github"
    }
  }
  backend "remote" {
    organization = "nw-tfc-learn"
    workspaces {
      name = "terraform-demo-cloud-agents-aci-container-registry"
    }
  }
  required_version = ">= 0.13"
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy       = false
      purge_soft_deleted_keys_on_destroy = false
    }
  }
}

provider "github" {
  token = var.github_token
  owner = var.github_organization
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-cr-resource-group"
  location = var.location
}

data "github_repository" "demo" {
  full_name = "${var.github_organization}/terraform-demo-cloud-agents-aci-docker-file"
}

resource "github_actions_secret" "container_registry_url" {
  repository      = data.github_repository.demo.name
  secret_name     = "BUILD_CONTAINER_REGISTRY_URL"
  plaintext_value = azurerm_container_registry.demo.login_server
}

resource "github_actions_secret" "container_registry_username" {
  repository      = data.github_repository.demo.name
  secret_name     = "BUILD_CONTAINER_REGISTRY_USERNAME"
  plaintext_value = azurerm_container_registry.demo.admin_username
}

resource "github_actions_secret" "container_registry_password" {
  repository      = data.github_repository.demo.name
  secret_name     = "BUILD_CONTAINER_REGISTRY_PASSWORD"
  plaintext_value = azurerm_container_registry.demo.admin_password
}

resource "azurerm_container_registry" "demo" {
  name                = "${var.prefix}ContainerRegistry"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Premium"
  admin_enabled       = true
  georeplications {
    location = var.location_secondary
    tags = merge(var.tags, {
      resource-type = "ContainerRegistryGeoReplication"
      resource-sku  = "Premium"
    })
  }
  tags = merge(var.tags, {
    resource-type = "ContainerRegistry"
    resource-sku  = "Premium"
  })

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.demo.id
    ]
  }

  encryption {
    enabled            = true
    key_vault_key_id   = azurerm_key_vault_key.demo.id
    identity_client_id = azurerm_user_assigned_identity.demo.client_id
  }
}

resource "azurerm_user_assigned_identity" "demo" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  name                = "${var.prefix}-cr-user-assigned-identity"
  tags = merge(var.tags, {
    resource-type = "UserAssignedIdentity"
    resource-sku  = "None"
  })
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "demo" {
  name                       = "${var.prefix}-cr-key-vault"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
  tags = merge(var.tags, {
    resource-type = "KeyVault"
    resource-sku  = "Standard"
  })

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Get",
      "UnwrapKey",
      "WrapKey"
    ]
  }

  access_policy {
    tenant_id = azurerm_user_assigned_identity.demo.tenant_id
    object_id = azurerm_user_assigned_identity.demo.principal_id

    key_permissions = [
      "Get",
      "UnwrapKey",
      "WrapKey"
    ]
  }
}

resource "azurerm_key_vault_key" "demo" {
  name         = "container-registry-key"
  key_vault_id = azurerm_key_vault.demo.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey"
  ]
}