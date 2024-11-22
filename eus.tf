# resource "azurerm_virtual_hub" "eus" {
#     name                = "eus"
#     resource_group_name = azurerm_resource_group.vwan.name
#     location            = "East US2"
#     virtual_wan_id      = azurerm_virtual_wan.this.id
#     address_prefix    = "10.11.0.0/23"
# }