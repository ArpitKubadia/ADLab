# Network Interface
resource "azurerm_network_interface" "eh_ctf-vm-winserv2019-nic" {
  name                 = "eh_ctf-vm-winserv2019-nic"
  location             = data.azurerm_resource_group.eh_ctf-rg.location
  resource_group_name  = data.azurerm_resource_group.eh_ctf-rg.name

  ip_configuration {
    name                          = "eh_ctf-vm-winserv2019-config"
    subnet_id                     = azurerm_subnet.eh_ctf-subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.13.37.100"
  }
}

resource "azurerm_network_interface_nat_rule_association" "eh_ctf-vm-winserv2019-nic-nat" {
  network_interface_id  = azurerm_network_interface.eh_ctf-vm-winserv2019-nic.id
  ip_configuration_name = "eh_ctf-vm-winserv2019-config"
  nat_rule_id           = azurerm_lb_nat_rule.eh_ctf-lb-nat-http.id
}

# Virtual Machine
resource "azurerm_windows_virtual_machine" "eh_ctf-vm-winserv2019" {
  name                = "eh_ctf-vm-winserv2019"
  computer_name       = var.winserv2019-hostname
  size                = var.winserv2019-size
  provision_vm_agent  = true
  enable_automatic_updates = true
  resource_group_name = data.azurerm_resource_group.eh_ctf-rg.name
  location            = data.azurerm_resource_group.eh_ctf-rg.location
  timezone            = var.timezone
  admin_username      = var.windows-user
  admin_password      = random_string.windowspass.result
  custom_data         = local.custom_data_content
  network_interface_ids = [
    azurerm_network_interface.eh_ctf-vm-winserv2019-nic.id,
  ]

  os_disk {
    name                 = "eh_ctf-vm-winserv2019-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  additional_unattend_content {
    setting = "AutoLogon"
    content = "<AutoLogon><Password><Value>${random_string.windowspass.result}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.windows-user}</Username></AutoLogon>"
  }

  additional_unattend_content {
    setting = "FirstLogonCommands"
    content = "${file("${path.module}/files/FirstLogonCommands.xml")}"
  }

  tags = {
    DoNotAutoShutDown = "yes"
  }
}