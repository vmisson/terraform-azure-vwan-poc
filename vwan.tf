resource "azurerm_resource_group" "vwan" {
  name     = "rg-vwan"
  location = "North Europe"
}

resource "azurerm_virtual_wan" "this" {
  name                = "vwan-poc"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_resource_group.vwan.location
}

resource "random_string" "vpn-psk" {
  length = 32
}

