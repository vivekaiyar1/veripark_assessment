provider "azurerm" {
    subscription_id =var.app_sub_id
    client_id = var.client_id
    client_secret = var.client_secret
    tenant_id = var.tenant_id
    features {}
}

data "azurerm_client_config" "current" {}

resource "random_password" "mssql_admin_pwd" {
    length  = 10
    special = true
    min_lower = 3
    min_upper = 3
    min_numeric = 2
    min_special = 2
}

resource "azurerm_resource_group" "rg" {  
  name = "acme-ecommerce-rg"  
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {  
  name = "acme-vnet"  
  location = azurerm_resource_group.rg.location  
  resource_group_name = azurerm_resource_group.rg.name  
  address_space = ["10.0.0.0/24"]  
}

resource "azurerm_subnet" "frontend_subnet" {  
  name = "frontend-subnet"  
  resource_group_name = azurerm_resource_group.rg.name  
  virtual_network_name = azurerm_virtual_network.vnet.name  
  address_prefixes = ["10.0.1.0/25"]  
}

resource "azurerm_subnet" "middleware_subnet" {  
  name = "middleware-subnet"  
  resource_group_name = azurerm_resource_group.rg.name  
  virtual_network_name = azurerm_virtual_network.vnet.name  
  address_prefixes = ["10.0.2.0/25"]  
}

resource "azurerm_subnet" "db_subnet" {  
  name = "db-subnet"  
  resource_group_name = azurerm_resource_group.rg.name  
  virtual_network_name = azurerm_virtual_network.vnet.name  
  address_prefixes = ["10.0.3.0/25"]  
}

resource "azurerm_private_dns_zone" "app_service_dns_zone" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "mssql_dns_zone" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "keyvault_dns_zone" {
    name                = "privatelink.vaultcore.azure.net"
    resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "app_service_dns_zone" {
  name = "acme-vnet-zone"
  resource_group_name =  azurerm_resource_group.rg.name 
  private_dns_zone_name = azurerm_private_dns_zone.app_service_dns_zone.name
  virtual_network_id = azurerm_virtual_network.vnet.id
  registration_enabled = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "mssql_dns_zone" {
  name = "acme-vnet-zone"
  resource_group_name =  azurerm_resource_group.rg.name 
  private_dns_zone_name = azurerm_private_dns_zone.mssql_dns_zone.name
  virtual_network_id = azurerm_virtual_network.vnet.id
  registration_enabled = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault_dns_zone" {
    name = "acme-vnet-zone"
    resource_group_name =  azurerm_resource_group.rg.name 
    private_dns_zone_name = azurerm_private_dns_zone.keyvault_dns_zone.name
    virtual_network_id = azurerm_virtual_network.vnet.id
    registration_enabled = false
  }


resource "azurerm_network_security_group" "frontend_nsg" {
  name = "frontend-nsg"
  location = var.location
  resource_group_name = azurerm_resource_group.rg.name

}

resource "azurerm_network_security_rule" "allow_from_internet_frontend" {
  name                        = "AllowInternet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "10.0.1.0/25"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.frontend_nsg.name
}

resource "azurerm_network_security_rule" "deny_other_protocols_frontend" {
  name                        = "DenyAll"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "10.0.1.0/25"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.frontend_nsg.name
}

resource "azurerm_subnet_network_security_group_association" "attach_subnet_frontend" {
  subnet_id                 = azurerm_subnet.frontend_subnet.id
  network_security_group_id = azurerm_network_security_group.frontend_nsg.id
}


resource "azurerm_network_security_group" "middleware_nsg" {
  name = "middleware-nsg"
  location = var.location
  resource_group_name = azurerm_resource_group.rg.name

}

resource "azurerm_network_security_rule" "allow_from_frontend" {
  name                        = "AllowFrontend"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "10.0.2.0/25"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.frontend_nsg.name
}

resource "azurerm_network_security_rule" "deny_other_protocols_middleware" {
  name                        = "DenyAll"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "10.0.2.0/25"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.middleware_nsg.name
}

resource "azurerm_subnet_network_security_group_association" "attach_subnet_middleware" {
    subnet_id                 = azurerm_subnet.middleware_subnet.id
    network_security_group_id = azurerm_network_security_group.middleware_nsg.id
}

resource "azurerm_network_security_group" "db_nsg" {
  name = "db-nsg"
  location = var.location
  resource_group_name = azurerm_resource_group.rg.name

}

resource "azurerm_network_security_rule" "allow_from_middleware" {
  name                        = "AllowMiddleware"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3306"
  source_address_prefix       = "*"
  destination_address_prefix  = "10.0.3.0/25"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.db_nsg.name
}

resource "azurerm_network_security_rule" "deny_other_protocols_db" {
  name                        = "DenyAll"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "10.0.3.0/25"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.db_nsg.name
}

resource "azurerm_subnet_network_security_group_association" "attach_subnet_db" {
    subnet_id                 = azurerm_subnet.db_subnet.id
    network_security_group_id = azurerm_network_security_group.db_nsg.id
}

resource "azurerm_app_service_plan" "backend_plan" {  
  name = "acme-backend-app-service-plan"  
  location = azurerm_resource_group.rg.location  
  resource_group_name = azurerm_resource_group.rg.name  
  kind = "Linux"  
  reserved = true  
  sku {  
    tier = "Standard"  
    size = "S1"  
 }  
}

resource "azurerm_app_service" "backend_app" {  
  name = "acme-backend-api"  
  location = azurerm_resource_group.rg.location  
  resource_group_name = azurerm_resource_group.rg.name  
  app_service_plan_id = azurerm_app_service_plan.backend_plan.id  
  app_settings = {  
    "WEBSITE_NODE_DEFAULT_VERSION" = "14"  
  }  
}

resource "azurerm_private_endpoint" "backend_private_endpoint" {  
  name = "backend-private-endpoint"  
  resource_group_name = azurerm_resource_group.rg.name  
  location = azurerm_resource_group.rg.location  
  subnet_id = azurerm_subnet.frontend_subnet.id  
  private_service_connection {  
    name = "backend-private-connection"  
    private_connection_resource_id = azurerm_app_service.backend_app.id  
    is_manual_connection = false  
    subresource_names = ["sites"]  
    }  
}

resource "azurerm_app_service_plan" "middleware_plan" {  
  name = "acme-middleware-app-service-plan"  
  location = azurerm_resource_group.rg.location  
  resource_group_name = azurerm_resource_group.rg.name  
  kind = "Linux"  
  reserved = true  
  sku {  
    tier = "Standard"  
    size = "S1"  
  }  
}

resource "azurerm_app_service" "middleware_app" {  
  name = "acme-middleware-api"  
  location = azurerm_resource_group.rg.location  
  resource_group_name = azurerm_resource_group.rg.name  
  app_service_plan_id = azurerm_app_service_plan.middleware_plan.id  
  app_settings = {  
    "WEBSITE_NODE_DEFAULT_VERSION" = "14"  
  }  
}

resource "azurerm_private_endpoint" "middleware_private_endpoint" {  
  name = "middleware-private-endpoint"  
  resource_group_name = azurerm_resource_group.rg.name  
  location = azurerm_resource_group.rg.location  
  subnet_id = azurerm_subnet.middleware_subnet.id  
  private_service_connection {  
    name = "middleware-private-connection"  
    private_connection_resource_id = azurerm_app_service.middleware_app.id  
    is_manual_connection = false  
    subresource_names = ["sites"]  
    }  
}

resource "azurerm_key_vault" "key-vault" {
    name                = "acme-vault"
    location            = var.location
    resource_group_name = azurerm_resource_group.rg.name
    enabled_for_deployment          = true
    enabled_for_disk_encryption     = true
    enabled_for_template_deployment = true
    soft_delete_retention_days  = 7
    purge_protection_enabled    = true
    enable_rbac_authorization = true
    tenant_id = data.azurerm_client_config.current.tenant_id
    sku_name  = "premium"
  
    network_acls {
      bypass = "AzureServices"
      default_action = "Deny"
      ip_rules =   ["106.215.178.229/32"] #Add required IP addresses as needed for access to keyvault
    }

}

resource "azurerm_management_lock" "vault_lock" {
    name       = "acme-vault-lock"
    scope      = azurerm_key_vault.key-vault.id
    lock_level = "CanNotDelete"
    notes      = "Locked"
}

resource "azurerm_private_endpoint" "private_link" {
    name = "acme-vault-private-link"
    location = var.location
    resource_group_name = azurerm_resource_group.rg.name
    subnet_id = azurerm_subnet.db_subnet.id
  
  
  
    private_service_connection {
  
      name                           = "acme-vault-private-endpoint"
      is_manual_connection           = "false"
      private_connection_resource_id = azurerm_key_vault.key-vault.id
      subresource_names              =  [ "vault" ]
    }
  
}

data "azurerm_private_endpoint_connection" "pvt_link" {
    name                = azurerm_private_endpoint.private_link.name
    resource_group_name = azurerm_resource_group.rg.name
  
    depends_on = [azurerm_private_endpoint.private_link]
  }
  
  resource "azurerm_private_dns_a_record" "private_endpoint_a_record" {
    name                = "acme-vault"
    zone_name           = "privatelink.vaultcore.azure.net"
    resource_group_name = azurerm_resource_group.rg.name
    ttl                 = 300
    records             = [data.azurerm_private_endpoint_connection.pvt_link.private_service_connection[0].private_ip_address]
  }

resource "azurerm_mssql_server" "mssql_server" {  
  name = "acme-sql-server"  
  location = azurerm_resource_group.rg.location  
  resource_group_name = azurerm_resource_group.rg.name  
  version = "12.0"  
  administrator_login = "sqladmin"  
  administrator_login_password = random_password.mssql_admin_pwd.result
  minimum_tls_version          = "1.2"
  public_network_access_enabled = false
  transparent_data_encryption_key_vault_key_id = azurerm_key_vault_key.mssql_encrypt_key.id
}

resource "azurerm_mssql_database" "mssql_database" {
    name           = "acme-ecommerce-db"
    server_id      = azurerm_mssql_server.mssql_server.id
    license_type   = "LicenseIncluded"
    max_size_gb    = 50
    read_scale     = true
    sku_name       = "GP_S_Gen5_2"
    zone_redundant = true

 
 
    transparent_data_encryption_key_vault_key_id = azurerm_key_vault_key.mssql_encrypt_key.id
    transparent_data_encryption_key_automatic_rotation_enabled = true
  
    # prevent the possibility of accidental data loss
    lifecycle {
      prevent_destroy = true
    }

}

  resource "azurerm_key_vault_key" "mssql_encrypt_key" {
    name         = "acme-db-encrypt-key"
    key_vault_id =  azurerm_key_vault.key-vault.id
    key_type     = "RSA"
    key_size     = 2048
    key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]
  
}  

resource "azurerm_private_endpoint" "sql_private_endpoint" {
    name = "sql-db-private-link"
    location = var.location
    resource_group_name = azurerm_resource_group.rg.name
    subnet_id = azurerm_subnet.db_subnet.id
  
  
  
    private_service_connection {
  
      name                           = "sql-db-private-endpoint"
      is_manual_connection           = "false"
      private_connection_resource_id = azurerm_mssql_server.mssql_server.id 
      subresource_names              =  [ "sqlserver" ]
    }
  
}

data "azurerm_private_endpoint_connection" "db_pvt_link" {
    name                = azurerm_private_endpoint.private_link.name
    resource_group_name = azurerm_resource_group.rg.name
  
    depends_on = [azurerm_private_endpoint.private_link]
  }
  
  resource "azurerm_private_dns_a_record" "db_private_endpoint_a_record" {
    name                = "acme-sql-server"
    zone_name           = "privatelink.database.windows.net"
    resource_group_name = azurerm_resource_group.rg.name
    ttl                 = 300
    records             = [data.azurerm_private_endpoint_connection.db_pvt_link.private_service_connection[0].private_ip_address]
  }