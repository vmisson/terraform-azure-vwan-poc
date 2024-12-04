resource "azurerm_resource_group" "cus-onprem" {
  name     = "rg-${var.cus-name}-onprem"
  location = var.cus-location
}

resource "azurerm_virtual_network" "cus-onprem" {
  name                = "vnet-${var.cus-name}-onprem"
  resource_group_name = azurerm_resource_group.cus-onprem.name
  location            = azurerm_resource_group.cus-onprem.location
  address_space       = [var.cus-onprem-address-space]
}

resource "azurerm_subnet" "cus-gateway-subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.cus-onprem.name
  virtual_network_name = azurerm_virtual_network.cus-onprem.name
  address_prefixes     = [cidrsubnet(var.cus-onprem-address-space, "2", 0)]
}

resource "azurerm_subnet" "cus-vm-subnet" {
  name                 = "${var.cus-name}-vm-subnet"
  resource_group_name  = azurerm_resource_group.cus-onprem.name
  virtual_network_name = azurerm_virtual_network.cus-onprem.name
  address_prefixes     = [cidrsubnet(var.cus-onprem-address-space, "2", 1)]
}

resource "azurerm_public_ip" "cus-pip" {
  name                = "pip-${var.cus-name}-vng"
  location            = azurerm_resource_group.cus-onprem.location
  resource_group_name = azurerm_resource_group.cus-onprem.name
  allocation_method   = "Static"
}

resource "azurerm_virtual_network_gateway" "cus-vng" {
  name                = "vng-${var.cus-name}"
  location            = azurerm_resource_group.cus-onprem.location
  resource_group_name = azurerm_resource_group.cus-onprem.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  active_active       = false
  enable_bgp          = true

  bgp_settings {
    asn = var.cus-onprem-asn
  }

  ip_configuration {
    name                 = "vng-${var.cus-name}-ipconfig"
    public_ip_address_id = azurerm_public_ip.cus-pip.id
    subnet_id            = azurerm_subnet.cus-gateway-subnet.id
  }
}

resource "azurerm_network_interface" "cus-onprem" {
  name                = "vm-${var.cus-name}-onprem-nic"
  location            = azurerm_resource_group.cus-onprem.location
  resource_group_name = azurerm_resource_group.cus-onprem.name

  ip_configuration {
    name                          = "ifconfig"
    subnet_id                     = azurerm_subnet.cus-vm-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "cus-onprem" {
  name                            = "vm-${var.cus-name}-onprem"
  resource_group_name             = azurerm_resource_group.cus-onprem.name
  location                        = azurerm_resource_group.cus-onprem.location
  size                            = "Standard_DS1_v2"
  admin_username                  = "azurcuser"
  admin_password                  = "Password1234!"
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.cus-onprem.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "vm-${var.cus-name}-onprem-osdisk"
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

resource "azurerm_local_network_gateway" "cus-lng" {
  name                = "lng-${var.cus-name}"
  location            = azurerm_resource_group.cus-onprem.location
  resource_group_name = azurerm_resource_group.cus-onprem.name
  gateway_address     = sort(azurerm_vpn_gateway.cus.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips)[1]

  bgp_settings {
    asn                 = 65515
    bgp_peering_address = sort(azurerm_vpn_gateway.cus.bgp_settings[0].instance_0_bgp_peering_address[0].default_ips)[0]
  }
}

resource "azurerm_virtual_network_gateway_connection" "cus-vngc" {
  name                = "vngc-${var.cus-name}"
  location            = azurerm_resource_group.cus-onprem.location
  resource_group_name = azurerm_resource_group.cus-onprem.name

  type                       = "IPsec"
  enable_bgp                 = true
  virtual_network_gateway_id = azurerm_virtual_network_gateway.cus-vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.cus-lng.id
  shared_key                 = random_string.vpn-psk.result
}

resource "azurerm_virtual_network_gateway_connection" "cus-mpls-vngc" {
  name                = "vngc-mpls-${var.cus-name}"
  location            = azurerm_resource_group.cus-onprem.location
  resource_group_name = azurerm_resource_group.cus-onprem.name

  type                       = "IPsec"
  enable_bgp                 = false
  virtual_network_gateway_id = azurerm_virtual_network_gateway.cus-vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.mpls-lng.id
  shared_key                 = random_string.vpn-psk.result
}