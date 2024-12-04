resource "azurerm_resource_group" "vwan" {
  name     = "rg-vwan"
  location = "North Europe"
}

resource "azurerm_virtual_wan" "this" {
  name                = "vwan-poc"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_resource_group.vwan.location
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "law-vwan-poc"
  location            = azurerm_resource_group.vwan.location
  resource_group_name = azurerm_resource_group.vwan.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "random_string" "vpn-psk" {
  length = 32
}

