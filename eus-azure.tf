resource "azurerm_virtual_hub" "eus" {
  name                   = var.eus-name
  resource_group_name    = azurerm_resource_group.vwan.name
  location               = var.eus-location
  virtual_wan_id         = azurerm_virtual_wan.this.id
  address_prefix         = var.eus-vhub-address-space
  hub_routing_preference = "VpnGateway"
}

resource "azurerm_vpn_gateway" "eus" {
  name                = "vpng-${var.eus-name}"
  location            = azurerm_virtual_hub.eus.location
  resource_group_name = azurerm_resource_group.vwan.name
  virtual_hub_id      = azurerm_virtual_hub.eus.id
}

resource "azurerm_virtual_network" "eus-firewall" {
  name                = "vnet-${var.eus-name}-firewall"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_virtual_hub.eus.location
  address_space       = [var.eus-firewall-address-space]
}

resource "azurerm_subnet" "eus-firewall-mgmt-subnet" {
  name                 = "mgmt-subnet"
  resource_group_name  = azurerm_resource_group.vwan.name
  virtual_network_name = azurerm_virtual_network.eus-firewall.name
  address_prefixes     = [cidrsubnet(var.eus-firewall-address-space, "2", 0)]
}

resource "azurerm_subnet" "eus-firewall-untrust-subnet" {
  name                 = "untrust-subnet"
  resource_group_name  = azurerm_resource_group.vwan.name
  virtual_network_name = azurerm_virtual_network.eus-firewall.name
  address_prefixes     = [cidrsubnet(var.eus-firewall-address-space, "2", 1)]
}

resource "azurerm_subnet" "eus-firewall-trust-subnet" {
  name                 = "trust-subnet"
  resource_group_name  = azurerm_resource_group.vwan.name
  virtual_network_name = azurerm_virtual_network.eus-firewall.name
  address_prefixes     = [cidrsubnet(var.eus-firewall-address-space, "2", 2)]
}

resource "azurerm_subnet" "eus-azurefirewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.vwan.name
  virtual_network_name = azurerm_virtual_network.eus-firewall.name
  address_prefixes     = [cidrsubnet(var.eus-firewall-address-space, "2", 3)]
}

resource "azurerm_public_ip" "eus-pip-firewall" {
  name                = "pip-${var.eus-name}-firewall"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_virtual_hub.eus.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "eus-firewall" {
  name                = "fw-${var.eus-name}"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_virtual_hub.eus.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.eus-policy.id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.eus-azurefirewall.id
    public_ip_address_id = azurerm_public_ip.eus-pip-firewall.id
  }
}

resource "azurerm_firewall_policy" "eus-policy" {
  name                = "policy-${var.eus-name}"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_virtual_hub.eus.location
}

resource "azurerm_firewall_policy_rule_collection_group" "eus-fw-nrcg" {
  name               = "rcg-${var.eus-name}"
  firewall_policy_id = azurerm_firewall_policy.eus-policy.id
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

resource "azurerm_virtual_network" "eus-spoke1" {
  name                = "vnet-${var.eus-name}-spoke1"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_virtual_hub.eus.location
  address_space       = [var.eus-spoke1-address-space]
}

resource "azurerm_subnet" "eus-spoke1-subnet" {
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.vwan.name
  virtual_network_name = azurerm_virtual_network.eus-spoke1.name
  address_prefixes     = [var.eus-spoke1-address-space]
}

resource "azurerm_virtual_network" "eus-spoke2" {
  name                = "vnet-${var.eus-name}-spoke2"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_virtual_hub.eus.location
  address_space       = [var.eus-spoke2-address-space]
}

resource "azurerm_subnet" "eus-spoke2-subnet" {
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.vwan.name
  virtual_network_name = azurerm_virtual_network.eus-spoke2.name
  address_prefixes     = [var.eus-spoke2-address-space]
}

resource "azurerm_route_table" "eus-rt" {
  name                          = "rt-${var.eus-name}"
  resource_group_name           = azurerm_resource_group.vwan.name
  location                      = azurerm_virtual_hub.eus.location
  bgp_route_propagation_enabled = false

  route {
    name                   = "default"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.eus-firewall.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "eus-rt-spoke1" {
  subnet_id      = azurerm_subnet.eus-spoke1-subnet.id
  route_table_id = azurerm_route_table.eus-rt.id
}

resource "azurerm_subnet_route_table_association" "eus-rt-spoke2" {
  subnet_id      = azurerm_subnet.eus-spoke2-subnet.id
  route_table_id = azurerm_route_table.eus-rt.id
}

resource "azurerm_network_interface" "eus-spoke1" {
  name                = "vm-${var.eus-name}-spoke1-nic"
  location            = azurerm_virtual_hub.eus.location
  resource_group_name = azurerm_resource_group.vwan.name

  ip_configuration {
    name                          = "ifconfig"
    subnet_id                     = azurerm_subnet.eus-spoke1-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "eus-spoke1" {
  name                            = "vm-${var.eus-name}-spoke1"
  resource_group_name             = azurerm_resource_group.vwan.name
  location                        = azurerm_virtual_hub.eus.location
  size                            = "Standard_DS1_v2"
  admin_username                  = "azureuser"
  admin_password                  = "Password1234!"
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.eus-spoke1.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "vm-${var.eus-name}-spoke1-osdisk"
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

resource "azurerm_network_interface" "eus-spoke2" {
  name                = "vm-${var.eus-name}-spoke2-nic"
  location            = azurerm_virtual_hub.eus.location
  resource_group_name = azurerm_resource_group.vwan.name

  ip_configuration {
    name                          = "ifconfig"
    subnet_id                     = azurerm_subnet.eus-spoke2-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "eus-spoke2" {
  name                            = "vm-${var.eus-name}-spoke2"
  resource_group_name             = azurerm_resource_group.vwan.name
  location                        = azurerm_virtual_hub.eus.location
  size                            = "Standard_DS1_v2"
  admin_username                  = "azureuser"
  admin_password                  = "Password1234!"
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.eus-spoke2.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "vm-${var.eus-name}-spoke2-osdisk"
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

resource "azurerm_virtual_network_peering" "eus-firewall-to-spoke1" {
  name                         = "firewall-to-spoke1"
  resource_group_name          = azurerm_resource_group.vwan.name
  virtual_network_name         = azurerm_virtual_network.eus-firewall.name
  remote_virtual_network_id    = azurerm_virtual_network.eus-spoke1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "eus-spoke1-to-firewall" {
  name                         = "spoke1-to-firewall"
  resource_group_name          = azurerm_resource_group.vwan.name
  virtual_network_name         = azurerm_virtual_network.eus-spoke1.name
  remote_virtual_network_id    = azurerm_virtual_network.eus-firewall.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "eus-firewall-to-spoke2" {
  name                         = "firewall-to-spoke2"
  resource_group_name          = azurerm_resource_group.vwan.name
  virtual_network_name         = azurerm_virtual_network.eus-firewall.name
  remote_virtual_network_id    = azurerm_virtual_network.eus-spoke2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "eus-spoke2-to-firewall" {
  name                         = "spoke2-to-firewall"
  resource_group_name          = azurerm_resource_group.vwan.name
  virtual_network_name         = azurerm_virtual_network.eus-spoke2.name
  remote_virtual_network_id    = azurerm_virtual_network.eus-firewall.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_vpn_site" "eus-onprem" {
  name                = "${var.eus-name}-onprem"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_virtual_hub.eus.location
  virtual_wan_id      = azurerm_virtual_wan.this.id

  link {
    name       = "${var.eus-name}-onprem"
    ip_address = azurerm_public_ip.eus-pip.ip_address
    bgp {
      asn             = var.eus-onprem-asn
      peering_address = azurerm_virtual_network_gateway.eus-vng.bgp_settings[0].peering_addresses[0].default_addresses[0]
    }
  }
}

resource "azurerm_vpn_gateway_connection" "eus-vpn-connection" {
  name               = "${var.eus-name}-vpn-connection"
  vpn_gateway_id     = azurerm_vpn_gateway.eus.id
  remote_vpn_site_id = azurerm_vpn_site.eus-onprem.id

  vpn_link {
    name             = "${var.eus-name}-onprem"
    vpn_site_link_id = azurerm_vpn_site.eus-onprem.link[0].id
    shared_key       = random_string.vpn-psk.result
    bgp_enabled      = true
  }
}

resource "azurerm_virtual_hub_connection" "eus-fw" {
  name                      = "${var.eus-name}-fw"
  virtual_hub_id            = azurerm_virtual_hub.eus.id
  remote_virtual_network_id = azurerm_virtual_network.eus-firewall.id

  routing {
    static_vnet_route {
      name = "${var.eus-name}-spokes"
      address_prefixes = [
        var.eus-spoke1-address-space,
        var.eus-spoke2-address-space
      ]
      next_hop_ip_address = azurerm_firewall.eus-firewall.ip_configuration[0].private_ip_address
    }
  }

  depends_on = [ azurerm_vpn_gateway.eus ]
}

resource "azurerm_route_map" "eus-rm" {
  name           = "rm-${var.eus-name}"
  virtual_hub_id = azurerm_virtual_hub.eus.id
}
