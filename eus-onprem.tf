resource "azurerm_resource_group" "eus-onprem" {
  name     = "rg-${var.eus-name}-onprem"
  location = var.eus-location
}

resource "azurerm_virtual_network" "eus-onprem" {
  name                = "vnet-${var.eus-name}-onprem"
  resource_group_name = azurerm_resource_group.eus-onprem.name
  location            = azurerm_resource_group.eus-onprem.location
  address_space       = [var.eus-onprem-address-space]
}

resource "azurerm_subnet" "eus-gateway-subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.eus-onprem.name
  virtual_network_name = azurerm_virtual_network.eus-onprem.name
  address_prefixes     = [cidrsubnet(var.eus-onprem-address-space, "2", 0)]
}

resource "azurerm_subnet" "eus-vm-subnet" {
  name                 = "${var.eus-name}-vm-subnet"
  resource_group_name  = azurerm_resource_group.eus-onprem.name
  virtual_network_name = azurerm_virtual_network.eus-onprem.name
  address_prefixes     = [cidrsubnet(var.eus-onprem-address-space, "2", 1)]
}

resource "azurerm_public_ip" "eus-pip" {
  name                = "pip-${var.eus-name}-vng"
  location            = azurerm_resource_group.eus-onprem.location
  resource_group_name = azurerm_resource_group.eus-onprem.name
  allocation_method   = "Static"
}

resource "azurerm_virtual_network_gateway" "eus-vng" {
  name                = "vng-${var.eus-name}"
  location            = azurerm_resource_group.eus-onprem.location
  resource_group_name = azurerm_resource_group.eus-onprem.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  active_active       = false
  enable_bgp          = true

  bgp_settings {
    asn = var.eus-onprem-asn
  }

  ip_configuration {
    name                 = "vng-${var.eus-name}-ipconfig"
    public_ip_address_id = azurerm_public_ip.eus-pip.id
    subnet_id            = azurerm_subnet.eus-gateway-subnet.id
  }
}

resource "azurerm_network_interface" "eus-onprem" {
  name                = "vm-${var.eus-name}-onprem-nic"
  location            = azurerm_resource_group.eus-onprem.location
  resource_group_name = azurerm_resource_group.eus-onprem.name

  ip_configuration {
    name                          = "ifconfig"
    subnet_id                     = azurerm_subnet.eus-vm-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "eus-onprem" {
  name                            = "vm-${var.eus-name}-onprem"
  resource_group_name             = azurerm_resource_group.eus-onprem.name
  location                        = azurerm_resource_group.eus-onprem.location
  size                            = "Standard_DS1_v2"
  admin_username                  = "azureuser"
  admin_password                  = "Password1234!"
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.eus-onprem.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "vm-${var.eus-name}-onprem-osdisk"
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

resource "azurerm_local_network_gateway" "eus-lng" {
  name                = "lng-${var.eus-name}"
  location            = azurerm_resource_group.eus-onprem.location
  resource_group_name = azurerm_resource_group.eus-onprem.name
  gateway_address     = sort(azurerm_vpn_gateway.eus.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips)[1]

  bgp_settings {
    asn                 = 65515
    bgp_peering_address = sort(azurerm_vpn_gateway.eus.bgp_settings[0].instance_0_bgp_peering_address[0].default_ips)[0]
  }
}

resource "azurerm_virtual_network_gateway_connection" "eus-vngc" {
  name                = "vngc-${var.eus-name}"
  location            = azurerm_resource_group.eus-onprem.location
  resource_group_name = azurerm_resource_group.eus-onprem.name

  type                       = "IPsec"
  enable_bgp                 = true
  virtual_network_gateway_id = azurerm_virtual_network_gateway.eus-vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.eus-lng.id
  shared_key                 = random_string.vpn-psk.result
}

resource "azurerm_virtual_network_gateway_connection" "eus-mpls-vngc" {
  name                = "vngc-mpls-${var.eus-name}"
  location            = azurerm_resource_group.eus-onprem.location
  resource_group_name = azurerm_resource_group.eus-onprem.name

  type                       = "IPsec"
  enable_bgp                 = false
  virtual_network_gateway_id = azurerm_virtual_network_gateway.eus-vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.mpls-lng.id
  shared_key                 = random_string.vpn-psk.result
}