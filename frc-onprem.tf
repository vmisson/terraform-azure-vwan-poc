resource "azurerm_resource_group" "frc-onprem" {
  name     = "rg-${var.frc-name}-onprem"
  location = var.frc-location
}

resource "azurerm_virtual_network" "frc-onprem" {
  name                = "vnet-${var.frc-name}-onprem"
  resource_group_name = azurerm_resource_group.frc-onprem.name
  location            = azurerm_resource_group.frc-onprem.location
  address_space       = [var.frc-onprem-address-space]
}

resource "azurerm_subnet" "frc-gateway-subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.frc-onprem.name
  virtual_network_name = azurerm_virtual_network.frc-onprem.name
  address_prefixes     = [cidrsubnet(var.frc-onprem-address-space, "2", 0)]
}

resource "azurerm_subnet" "frc-vm-subnet" {
  name                 = "${var.frc-name}-vm-subnet"
  resource_group_name  = azurerm_resource_group.frc-onprem.name
  virtual_network_name = azurerm_virtual_network.frc-onprem.name
  address_prefixes     = [cidrsubnet(var.frc-onprem-address-space, "2", 1)]
}

resource "azurerm_public_ip" "frc-pip" {
  name                = "pip-${var.frc-name}-vng"
  location            = azurerm_resource_group.frc-onprem.location
  resource_group_name = azurerm_resource_group.frc-onprem.name
  allocation_method   = "Static"
}

resource "azurerm_virtual_network_gateway" "frc-vng" {
  name                = "vng-${var.frc-name}"
  location            = azurerm_resource_group.frc-onprem.location
  resource_group_name = azurerm_resource_group.frc-onprem.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  active_active       = false
  enable_bgp          = true

  bgp_settings {
    asn = var.frc-onprem-asn
  }

  ip_configuration {
    name                 = "vng-${var.frc-name}-ipconfig"
    public_ip_address_id = azurerm_public_ip.frc-pip.id
    subnet_id            = azurerm_subnet.frc-gateway-subnet.id
  }
}

resource "azurerm_network_interface" "frc-onprem" {
  name                = "vm-${var.frc-name}-onprem-nic"
  location            = azurerm_resource_group.frc-onprem.location
  resource_group_name = azurerm_resource_group.frc-onprem.name

  ip_configuration {
    name                          = "ifconfig"
    subnet_id                     = azurerm_subnet.frc-vm-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "frc-onprem" {
  name                            = "vm-${var.frc-name}-onprem"
  resource_group_name             = azurerm_resource_group.frc-onprem.name
  location                        = azurerm_resource_group.frc-onprem.location
  size                            = "Standard_DS1_v2"
  admin_username                  = "azureuser"
  admin_password                  = "Password1234!"
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.frc-onprem.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "vm-${var.frc-name}-onprem-osdisk"
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

resource "azurerm_local_network_gateway" "frc-lng" {
  name                = "lng-${var.frc-name}"
  location            = azurerm_resource_group.frc-onprem.location
  resource_group_name = azurerm_resource_group.frc-onprem.name
  gateway_address     = sort(azurerm_vpn_gateway.frc.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips)[1]
  bgp_settings {
    asn                 = 65515
    bgp_peering_address = sort(azurerm_vpn_gateway.frc.bgp_settings[0].instance_0_bgp_peering_address[0].default_ips)[0]
  }
}

resource "azurerm_virtual_network_gateway_connection" "frc-vngc" {
  name                = "vngc-${var.frc-name}"
  location            = azurerm_resource_group.frc-onprem.location
  resource_group_name = azurerm_resource_group.frc-onprem.name

  type                       = "IPsec"
  enable_bgp                 = true
  virtual_network_gateway_id = azurerm_virtual_network_gateway.frc-vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.frc-lng.id
  shared_key                 = random_string.vpn-psk.result
}

resource "azurerm_virtual_network_gateway_connection" "frc-mpls-vngc" {
  name                = "vngc-mpls-${var.frc-name}"
  location            = azurerm_resource_group.frc-onprem.location
  resource_group_name = azurerm_resource_group.frc-onprem.name

  type                       = "IPsec"
  enable_bgp                 = false
  virtual_network_gateway_id = azurerm_virtual_network_gateway.frc-vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.mpls-lng.id
  shared_key                 = random_string.vpn-psk.result
}