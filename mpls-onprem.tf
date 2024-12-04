resource "azurerm_resource_group" "mpls-onprem" {
  name     = "rg-${var.mpls-name}-onprem"
  location = var.mpls-location
}

resource "azurerm_virtual_network" "mpls-onprem" {
  name                = "vnet-${var.mpls-name}-onprem"
  resource_group_name = azurerm_resource_group.mpls-onprem.name
  location            = azurerm_resource_group.mpls-onprem.location
  address_space       = [var.mpls-onprem-address-space]
}

resource "azurerm_subnet" "mpls-gateway-subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.mpls-onprem.name
  virtual_network_name = azurerm_virtual_network.mpls-onprem.name
  address_prefixes     = [cidrsubnet(var.mpls-onprem-address-space, "2", 0)]
}

resource "azurerm_subnet" "mpls-vm-subnet" {
  name                 = "${var.mpls-name}-vm-subnet"
  resource_group_name  = azurerm_resource_group.mpls-onprem.name
  virtual_network_name = azurerm_virtual_network.mpls-onprem.name
  address_prefixes     = [cidrsubnet(var.mpls-onprem-address-space, "2", 1)]
}

resource "azurerm_public_ip" "mpls-pip" {
  name                = "pip-${var.mpls-name}-vng"
  location            = azurerm_resource_group.mpls-onprem.location
  resource_group_name = azurerm_resource_group.mpls-onprem.name
  allocation_method   = "Static"
}

resource "azurerm_virtual_network_gateway" "mpls-vng" {
  name                = "vng-${var.mpls-name}"
  location            = azurerm_resource_group.mpls-onprem.location
  resource_group_name = azurerm_resource_group.mpls-onprem.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  active_active       = false
  enable_bgp          = true

  bgp_settings {
    asn = var.mpls-onprem-asn
  }

  ip_configuration {
    name                 = "vng-${var.mpls-name}-ipconfig"
    public_ip_address_id = azurerm_public_ip.mpls-pip.id
    subnet_id            = azurerm_subnet.mpls-gateway-subnet.id
  }
}

resource "azurerm_network_interface" "mpls-onprem" {
  name                = "vm-${var.mpls-name}-onprem-nic"
  location            = azurerm_resource_group.mpls-onprem.location
  resource_group_name = azurerm_resource_group.mpls-onprem.name

  ip_configuration {
    name                          = "ifconfig"
    subnet_id                     = azurerm_subnet.mpls-vm-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "mpls-onprem" {
  name                            = "vm-${var.mpls-name}-onprem"
  resource_group_name             = azurerm_resource_group.mpls-onprem.name
  location                        = azurerm_resource_group.mpls-onprem.location
  size                            = "Standard_DS1_v2"
  admin_username                  = "azureuser"
  admin_password                  = "Password1234!"
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.mpls-onprem.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "vm-${var.mpls-name}-onprem-osdisk"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  boot_diagnostics {
  }
}

resource "azurerm_local_network_gateway" "mpls-lng" {
  name                = "lng-vng-${var.mpls-name}"
  location            = azurerm_resource_group.mpls-onprem.location
  resource_group_name = azurerm_resource_group.mpls-onprem.name
  gateway_address     = azurerm_public_ip.mpls-pip.ip_address
  address_space       = [var.mpls-onprem-address-space]
}

resource "azurerm_local_network_gateway" "mpls-lng-neu" {
  name                = "lng-vng-${var.neu-name}"
  location            = azurerm_resource_group.mpls-onprem.location
  resource_group_name = azurerm_resource_group.mpls-onprem.name
  gateway_address     = azurerm_public_ip.neu-pip.ip_address
  address_space       = ["10.100.0.0/24", "10.10.0.0/16"]
}

resource "azurerm_local_network_gateway" "mpls-lng-frc" {
  name                = "lng-vng-${var.frc-name}"
  location            = azurerm_resource_group.mpls-onprem.location
  resource_group_name = azurerm_resource_group.mpls-onprem.name
  gateway_address     = azurerm_public_ip.frc-pip.ip_address
  address_space       = ["10.100.1.0/24", "10.20.0.0/16"]
}

resource "azurerm_local_network_gateway" "mpls-lng-eus" {
  name                = "lng-vng-${var.eus-name}"
  location            = azurerm_resource_group.mpls-onprem.location
  resource_group_name = azurerm_resource_group.mpls-onprem.name
  gateway_address     = azurerm_public_ip.eus-pip.ip_address
  address_space       = ["10.100.2.0/24", "10.30.0.0/16"]
}

resource "azurerm_local_network_gateway" "mpls-lng-cus" {
  name                = "lng-vng-${var.cus-name}"
  location            = azurerm_resource_group.mpls-onprem.location
  resource_group_name = azurerm_resource_group.mpls-onprem.name
  gateway_address     = azurerm_public_ip.cus-pip.ip_address
  address_space       = ["10.100.3.0/24", "10.40.0.0/16"]
}

resource "azurerm_virtual_network_gateway_connection" "mpls-neu-vngc" {
  name                = "vngc-${var.neu-name}"
  location            = azurerm_resource_group.mpls-onprem.location
  resource_group_name = azurerm_resource_group.mpls-onprem.name

  type                       = "IPsec"
  enable_bgp                 = false
  virtual_network_gateway_id = azurerm_virtual_network_gateway.mpls-vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.mpls-lng-neu.id
  shared_key                 = random_string.vpn-psk.result
}

resource "azurerm_virtual_network_gateway_connection" "mpls-frc-vngc" {
  name                = "vngc-${var.frc-name}"
  location            = azurerm_resource_group.mpls-onprem.location
  resource_group_name = azurerm_resource_group.mpls-onprem.name

  type                       = "IPsec"
  enable_bgp                 = false
  virtual_network_gateway_id = azurerm_virtual_network_gateway.mpls-vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.mpls-lng-frc.id
  shared_key                 = random_string.vpn-psk.result
}

resource "azurerm_virtual_network_gateway_connection" "mpls-eus-vngc" {
  name                = "vngc-${var.eus-name}"
  location            = azurerm_resource_group.mpls-onprem.location
  resource_group_name = azurerm_resource_group.mpls-onprem.name

  type                       = "IPsec"
  enable_bgp                 = false
  virtual_network_gateway_id = azurerm_virtual_network_gateway.mpls-vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.mpls-lng-eus.id
  shared_key                 = random_string.vpn-psk.result
}

resource "azurerm_virtual_network_gateway_connection" "mpls-cus-vngc" {
  name                = "vngc-${var.cus-name}"
  location            = azurerm_resource_group.mpls-onprem.location
  resource_group_name = azurerm_resource_group.mpls-onprem.name

  type                       = "IPsec"
  enable_bgp                 = false
  virtual_network_gateway_id = azurerm_virtual_network_gateway.mpls-vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.mpls-lng-cus.id
  shared_key                 = random_string.vpn-psk.result
}