resource "azurerm_resource_group" "neu-onprem" {
  name     = "rg-${var.neu-name}-onprem"
  location = var.neu-location
}

resource "azurerm_virtual_network" "neu-onprem" {
  name                = "vnet-${var.neu-name}-onprem"
  resource_group_name = azurerm_resource_group.neu-onprem.name
  location            = azurerm_resource_group.neu-onprem.location
  address_space       = [var.neu-onprem-address-space]
}

resource "azurerm_subnet" "neu-gateway-subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.neu-onprem.name
  virtual_network_name = azurerm_virtual_network.neu-onprem.name
  address_prefixes     = [cidrsubnet(var.neu-onprem-address-space, "2", 0)]
}

resource "azurerm_subnet" "neu-vm-subnet" {
  name                 = "${var.neu-name}-vm-subnet"
  resource_group_name  = azurerm_resource_group.neu-onprem.name
  virtual_network_name = azurerm_virtual_network.neu-onprem.name
  address_prefixes     = [cidrsubnet(var.neu-onprem-address-space, "2", 1)]
}

resource "azurerm_public_ip" "neu-pip" {
  name                = "pip-${var.neu-name}-vng"
  location            = azurerm_resource_group.neu-onprem.location
  resource_group_name = azurerm_resource_group.neu-onprem.name
  allocation_method   = "Static"
}

resource "azurerm_virtual_network_gateway" "neu-vng" {
  name                = "vng-${var.neu-name}"
  location            = azurerm_resource_group.neu-onprem.location
  resource_group_name = azurerm_resource_group.neu-onprem.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  active_active       = false
  enable_bgp          = true

  bgp_settings {
    asn = var.neu-onprem-asn
  }

  ip_configuration {
    name                 = "vng-${var.neu-name}-ipconfig"
    public_ip_address_id = azurerm_public_ip.neu-pip.id
    subnet_id            = azurerm_subnet.neu-gateway-subnet.id
  }
}

resource "azurerm_network_interface" "neu-onprem" {
  name                = "vm-${var.neu-name}-onprem-nic"
  location            = azurerm_resource_group.neu-onprem.location
  resource_group_name = azurerm_resource_group.neu-onprem.name

  ip_configuration {
    name                          = "ifconfig"
    subnet_id                     = azurerm_subnet.neu-vm-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "neu-onprem" {
  name                            = "vm-${var.neu-name}-onprem"
  resource_group_name             = azurerm_resource_group.neu-onprem.name
  location                        = azurerm_resource_group.neu-onprem.location
  size                            = "Standard_DS1_v2"
  admin_username                  = "azureuser"
  admin_password                  = "Password1234!"
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.neu-onprem.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "vm-${var.neu-name}-onprem-osdisk"
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

resource "azurerm_local_network_gateway" "neu-lng" {
  name                = "lng-${var.neu-name}"
  location            = azurerm_resource_group.neu-onprem.location
  resource_group_name = azurerm_resource_group.neu-onprem.name
  gateway_address     = sort(azurerm_vpn_gateway.neu.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips)[1]

  bgp_settings {
    asn                 = 65515
    bgp_peering_address = sort(azurerm_vpn_gateway.neu.bgp_settings[0].instance_0_bgp_peering_address[0].default_ips)[0]
  }
}

resource "azurerm_virtual_network_gateway_connection" "neu-vngc" {
  name                = "vngc-${var.neu-name}"
  location            = azurerm_resource_group.neu-onprem.location
  resource_group_name = azurerm_resource_group.neu-onprem.name

  type                       = "IPsec"
  enable_bgp                 = true
  virtual_network_gateway_id = azurerm_virtual_network_gateway.neu-vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.neu-lng.id
  shared_key                 = random_string.vpn-psk.result
}

resource "azurerm_virtual_network_gateway_connection" "neu-mpls-vngc" {
  name                = "vngc-mpls-${var.neu-name}"
  location            = azurerm_resource_group.neu-onprem.location
  resource_group_name = azurerm_resource_group.neu-onprem.name

  type                       = "IPsec"
  enable_bgp                 = false
  virtual_network_gateway_id = azurerm_virtual_network_gateway.neu-vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.mpls-lng.id
  shared_key                 = random_string.vpn-psk.result
}