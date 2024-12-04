resource "azurerm_virtual_hub" "cus" {
  name                   = var.cus-name
  resource_group_name    = azurerm_resource_group.vwan.name
  location               = var.cus-location
  virtual_wan_id         = azurerm_virtual_wan.this.id
  address_prefix         = var.cus-vhub-address-space
  hub_routing_preference = "VpnGateway"
}

resource "azurerm_vpn_gateway" "cus" {
  name                = "vpng-${var.cus-name}"
  location            = azurerm_virtual_hub.cus.location
  resource_group_name = azurerm_resource_group.vwan.name
  virtual_hub_id      = azurerm_virtual_hub.cus.id
}

resource "azurerm_virtual_network" "cus-firewall" {
  name                = "vnet-${var.cus-name}-firewall"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_virtual_hub.cus.location
  address_space       = [var.cus-firewall-address-space]
}

resource "azurerm_subnet" "cus-firewall-mgmt-subnet" {
  name                 = "mgmt-subnet"
  resource_group_name  = azurerm_resource_group.vwan.name
  virtual_network_name = azurerm_virtual_network.cus-firewall.name
  address_prefixes     = [cidrsubnet(var.cus-firewall-address-space, "2", 0)]
}

resource "azurerm_subnet" "cus-firewall-untrust-subnet" {
  name                 = "untrust-subnet"
  resource_group_name  = azurerm_resource_group.vwan.name
  virtual_network_name = azurerm_virtual_network.cus-firewall.name
  address_prefixes     = [cidrsubnet(var.cus-firewall-address-space, "2", 1)]
}

resource "azurerm_subnet" "cus-firewall-trust-subnet" {
  name                 = "trust-subnet"
  resource_group_name  = azurerm_resource_group.vwan.name
  virtual_network_name = azurerm_virtual_network.cus-firewall.name
  address_prefixes     = [cidrsubnet(var.cus-firewall-address-space, "2", 2)]
}

resource "azurerm_subnet" "cus-azurefirewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.vwan.name
  virtual_network_name = azurerm_virtual_network.cus-firewall.name
  address_prefixes     = [cidrsubnet(var.cus-firewall-address-space, "2", 3)]
}

resource "azurerm_public_ip" "cus-pip-firewall" {
  name                = "pip-${var.cus-name}-firewall"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_virtual_hub.cus.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "cus-firewall" {
  name                = "fw-${var.cus-name}"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_virtual_hub.cus.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.cus-policy.id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.cus-azurefirewall.id
    public_ip_address_id = azurerm_public_ip.cus-pip-firewall.id
  }
}

resource "azurerm_firewall_policy" "cus-policy" {
  name                = "policy-${var.cus-name}"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_virtual_hub.cus.location
}

resource "azurerm_firewall_policy_rule_collection_group" "cus-fw-nrcg" {
  name               = "rcg-${var.cus-name}"
  firewall_policy_id = azurerm_firewall_policy.cus-policy.id
  priority           = 100
  network_rule_collection {
    name     = "network_rule_collection"
    priority = 1000
    action   = "Allow"
    rule {
      name                  = "allow-private"
      source_addresses      = ["10.0.0.0/8"]
      destination_addresses = ["10.0.0.0/8"]
      destination_ports     = ["*"]
      protocols             = ["TCP", "UDP", "ICMP"]
    }
  }
}

resource "azurerm_virtual_network" "cus-spoke1" {
  name                = "vnet-${var.cus-name}-spoke1"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_virtual_hub.cus.location
  address_space       = [var.cus-spoke1-address-space]
}

resource "azurerm_subnet" "cus-spoke1-subnet" {
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.vwan.name
  virtual_network_name = azurerm_virtual_network.cus-spoke1.name
  address_prefixes     = [var.cus-spoke1-address-space]
}

resource "azurerm_virtual_network" "cus-spoke2" {
  name                = "vnet-${var.cus-name}-spoke2"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_virtual_hub.cus.location
  address_space       = [var.cus-spoke2-address-space]
}

resource "azurerm_subnet" "cus-spoke2-subnet" {
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.vwan.name
  virtual_network_name = azurerm_virtual_network.cus-spoke2.name
  address_prefixes     = [var.cus-spoke2-address-space]
}

resource "azurerm_route_table" "cus-rt" {
  name                          = "rt-${var.cus-name}"
  resource_group_name           = azurerm_resource_group.vwan.name
  location                      = azurerm_virtual_hub.cus.location
  bgp_route_propagation_enabled = false

  route {
    name                   = "default"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.cus-firewall.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "cus-rt-spoke1" {
  subnet_id      = azurerm_subnet.cus-spoke1-subnet.id
  route_table_id = azurerm_route_table.cus-rt.id
}

resource "azurerm_subnet_route_table_association" "cus-rt-spoke2" {
  subnet_id      = azurerm_subnet.cus-spoke2-subnet.id
  route_table_id = azurerm_route_table.cus-rt.id
}

resource "azurerm_network_interface" "cus-spoke1" {
  name                = "vm-${var.cus-name}-spoke1-nic"
  location            = azurerm_virtual_hub.cus.location
  resource_group_name = azurerm_resource_group.vwan.name

  ip_configuration {
    name                          = "ifconfig"
    subnet_id                     = azurerm_subnet.cus-spoke1-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "cus-spoke1" {
  name                            = "vm-${var.cus-name}-spoke1"
  resource_group_name             = azurerm_resource_group.vwan.name
  location                        = azurerm_virtual_hub.cus.location
  size                            = "Standard_DS1_v2"
  admin_username                  = "azurcuser"
  admin_password                  = "Password1234!"
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.cus-spoke1.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "vm-${var.cus-name}-spoke1-osdisk"
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

resource "azurerm_network_interface" "cus-spoke2" {
  name                = "vm-${var.cus-name}-spoke2-nic"
  location            = azurerm_virtual_hub.cus.location
  resource_group_name = azurerm_resource_group.vwan.name

  ip_configuration {
    name                          = "ifconfig"
    subnet_id                     = azurerm_subnet.cus-spoke2-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "cus-spoke2" {
  name                            = "vm-${var.cus-name}-spoke2"
  resource_group_name             = azurerm_resource_group.vwan.name
  location                        = azurerm_virtual_hub.cus.location
  size                            = "Standard_DS1_v2"
  admin_username                  = "azurcuser"
  admin_password                  = "Password1234!"
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.cus-spoke2.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "vm-${var.cus-name}-spoke2-osdisk"
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

resource "azurerm_virtual_network_peering" "cus-firewall-to-spoke1" {
  name                         = "firewall-to-spoke1"
  resource_group_name          = azurerm_resource_group.vwan.name
  virtual_network_name         = azurerm_virtual_network.cus-firewall.name
  remote_virtual_network_id    = azurerm_virtual_network.cus-spoke1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "cus-spoke1-to-firewall" {
  name                         = "spoke1-to-firewall"
  resource_group_name          = azurerm_resource_group.vwan.name
  virtual_network_name         = azurerm_virtual_network.cus-spoke1.name
  remote_virtual_network_id    = azurerm_virtual_network.cus-firewall.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "cus-firewall-to-spoke2" {
  name                         = "firewall-to-spoke2"
  resource_group_name          = azurerm_resource_group.vwan.name
  virtual_network_name         = azurerm_virtual_network.cus-firewall.name
  remote_virtual_network_id    = azurerm_virtual_network.cus-spoke2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "cus-spoke2-to-firewall" {
  name                         = "spoke2-to-firewall"
  resource_group_name          = azurerm_resource_group.vwan.name
  virtual_network_name         = azurerm_virtual_network.cus-spoke2.name
  remote_virtual_network_id    = azurerm_virtual_network.cus-firewall.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_vpn_site" "cus-onprem" {
  name                = "${var.cus-name}-onprem"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_virtual_hub.cus.location
  virtual_wan_id      = azurerm_virtual_wan.this.id

  link {
    name       = "${var.cus-name}-onprem"
    ip_address = azurerm_public_ip.cus-pip.ip_address
    bgp {
      asn             = var.cus-onprem-asn
      peering_address = azurerm_virtual_network_gateway.cus-vng.bgp_settings[0].peering_addresses[0].default_addresses[0]
    }
  }
}

resource "azurerm_vpn_gateway_connection" "cus-vpn-connection" {
  name               = "${var.cus-name}-vpn-connection"
  vpn_gateway_id     = azurerm_vpn_gateway.cus.id
  remote_vpn_site_id = azurerm_vpn_site.cus-onprem.id

  vpn_link {
    name             = "${var.cus-name}-onprem"
    vpn_site_link_id = azurerm_vpn_site.cus-onprem.link[0].id
    shared_key       = random_string.vpn-psk.result
    bgp_enabled      = true
  }
}

resource "azurerm_virtual_hub_connection" "cus-fw" {
  name                      = "${var.cus-name}-fw"
  virtual_hub_id            = azurerm_virtual_hub.cus.id
  remote_virtual_network_id = azurerm_virtual_network.cus-firewall.id

  routing {
    static_vnet_route {
      name = "${var.cus-name}-spokes"
      address_prefixes = [
        var.cus-spoke1-address-space,
        var.cus-spoke2-address-space
      ]
      next_hop_ip_address = azurerm_firewall.cus-firewall.ip_configuration[0].private_ip_address
    }
  }

  depends_on = [ azurerm_vpn_gateway.cus ]
}

resource "azurerm_route_map" "cus-rm" {
  name           = "rm-${var.cus-name}"
  virtual_hub_id = azurerm_virtual_hub.cus.id
}
