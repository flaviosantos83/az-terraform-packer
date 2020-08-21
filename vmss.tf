provider "azurerm" {
    features {}
    version = "~> 2.22"
    subscription_id = "12037468-f761-4ce3-aa8a-353b1d76c6b4"
    client_id       = "ccd5ad5a-ddee-43d6-b396-f912b2dd5cf7"
    client_secret   = "IJ-1PXU0_-TCKDnx_GucGnDjxxwrofnFW7"
    tenant_id       = "66fc9de7-c475-401c-a2e2-0828300b4aa5"
}

resource "azurerm_resource_group" "vmss" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = "teste"
  }
}

resource "azurerm_virtual_network" "vmss" {
  name                = "vmss-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.vmss.name

  tags = {
    environment = "teste"
  }
}

resource "azurerm_subnet" "vmss" {
  name                 = "vmss-subnet"
  resource_group_name  = azurerm_resource_group.vmss.name
  virtual_network_name = azurerm_virtual_network.vmss.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "vmss" {
  name                         = "vmss-public-ip"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.vmss.name
  allocation_method            = "Static"
  domain_name_label            = azurerm_resource_group.vmss.name

  tags = {
    environment = "teste"
  }
}

resource "azurerm_lb" "vmss" {
  name                = "vmss-lb"
  location            = var.location
  resource_group_name = azurerm_resource_group.vmss.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.vmss.id
  }

  tags = {
    environment = "teste"
  }
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  resource_group_name = azurerm_resource_group.vmss.name
  loadbalancer_id     = azurerm_lb.vmss.id
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "vmss" {
  resource_group_name = azurerm_resource_group.vmss.name
  loadbalancer_id     = azurerm_lb.vmss.id
  name                = "ssh-running-probe"
  port                = var.application_port
}

resource "azurerm_lb_rule" "lbnatrule" {
  resource_group_name            = azurerm_resource_group.vmss.name
  loadbalancer_id                = azurerm_lb.vmss.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = var.application_port
  backend_port                   = var.application_port
  backend_address_pool_id        = azurerm_lb_backend_address_pool.bpepool.id
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.vmss.id
}

data "azurerm_resource_group" "image" {
  name = "myResourceGroup"
}

data "azurerm_image" "image" {
  name                = "myPackerUbuntu1804"
  resource_group_name = data.azurerm_resource_group.image.name
}

resource "azurerm_virtual_machine_scale_set" "vmss" {
  name                = "vmscaleset"
  location            = var.location
  resource_group_name = azurerm_resource_group.vmss.name
  upgrade_policy_mode = "Manual"

  sku {
    name     = "Standard_DS1_v2"
    tier     = "Standard"
    capacity = 2
  }

  storage_profile_image_reference {
    id=data.azurerm_image.image.id
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun          = 0
    caching        = "ReadWrite"
    create_option  = "Empty"
    disk_size_gb   = 10
  }

  os_profile {
    computer_name_prefix = "vmlab"
    admin_username       = "azureuser"
    admin_password       = "Passwword1234"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDftoBeLaXEc6WSxXH9fNU3sgMO1cV0sDVsF6LpoWlwBXZXAfsdBXFUdzzwr/8bDYMy6/pNgTHH95cRgUDcxnQvNFXvaw9PP0a6hn0d99nvtBBs+53RwNnLlaxwHdokaJW5eLGxAnSciihrZ2lS9YvjjHq/Cb4Lh+bolUKahLf76U4U0A7SNURKI4QCtiBtmFUEzaX5vQ1aq1SfmU5qPJkKR9ANgRNtU4RMTjhhtk7TvYx/bpLynxbZ7Qsvz6+cSmbMcST+y70IwioNQhH6yfB3/wnQ98p9QWuM6pMhHlguXwSIqvu204vl5mRCsJQ+3Ym0I9mW7NSnDUxDMJxDIaE1 bitnami@jenkins"
    }
    ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC5vbxOrgfjiOJqpTgmB0MpllLkwyzNtemexyNWBgXQEH/O6kott44VihFnvMZHLco0NCTN617uFa+VugHoOWBxj0mdsqh/I/vljqbxxGSLfSdUJEkcwxcyQsMDRJP0qFyHBPCpMSmApQyIz1w8tfCpS12177Mc40ihd+OllaMot62xaGk+/cPsXKQbRNOjH1N5UukYO8dGoUOhDAdQAHwtVYPpEDAz/I3a5JHfmTk0Y1OXn16thQLrGsUUv0Mz16fBC7Va0tJR/b62WMHt/JjnSKUiGm4TQ5a3koPMi5UO6ZnoKAy11K85LdN/lUl3xmaPi8FdW3lTtXAAfSnyeVQ/1gh2rPzk5fGS4aJSK/2BxgHkvlxY/Hy2I1BjlUk3jn6ephy8oKZTEOSonwu1+pDOKAvAZpomTVVO2NS7x0GJBR93XJlK91a7PO9yuG3alZaFHPojkQfmzwieG3ZbdrBGjzQ0QIEamLPBsMNVuagtPC7qkyWVo8hJWehfi+8j/aRI3dXC1E3ArNX9SYjV6gF/M2LI5hHIcy8HKSwMWsdkidSseyvKTCfC9Z4M/glnb/yCuzc2TLdrPmO5+m6/p1tLesWXm3CYWIO1nrNmFuzeoLFbGtMsht5d+vWXVWhjqKhE1rqU1OgZ/rUbUSN8Ox/O1y9Oq6UCDaFu65krQb9SyQ== flavio@MacbookAir.local"
        }
  }

  network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "IPConfiguration"
      subnet_id                              = azurerm_subnet.vmss.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
      primary = true
    }
  }
  
  tags = {
    environment = "teste"
  }
}