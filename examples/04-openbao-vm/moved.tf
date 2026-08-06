moved {
  from = azurerm_virtual_network.openbao
  to   = module.openbao.azurerm_virtual_network.this
}

moved {
  from = azurerm_subnet.openbao
  to   = module.openbao.azurerm_subnet.this
}

moved {
  from = azurerm_public_ip.openbao
  to   = module.openbao.azurerm_public_ip.this
}

moved {
  from = azurerm_network_security_group.openbao
  to   = module.openbao.azurerm_network_security_group.this
}

moved {
  from = azurerm_network_security_rule.operator
  to   = module.openbao.azurerm_network_security_rule.operator
}

moved {
  from = azurerm_network_security_rule.deny_all_inbound
  to   = module.openbao.azurerm_network_security_rule.deny_all_inbound
}

moved {
  from = azurerm_network_interface.openbao
  to   = module.openbao.azurerm_network_interface.this
}

moved {
  from = azurerm_network_interface_security_group_association.openbao
  to   = module.openbao.azurerm_network_interface_security_group_association.this
}

moved {
  from = azurerm_linux_virtual_machine.openbao
  to   = module.openbao.azurerm_linux_virtual_machine.this
}

moved {
  from = azurerm_managed_disk.raft
  to   = module.openbao.azurerm_managed_disk.raft
}

moved {
  from = azurerm_virtual_machine_data_disk_attachment.raft
  to   = module.openbao.azurerm_virtual_machine_data_disk_attachment.raft
}
