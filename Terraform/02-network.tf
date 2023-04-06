# Get the current public IP for deployment whitelisting
data "http" "public-ip" {
  url = "http://ipv4.icanhazip.com"
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "eh_ctf-vnet" {
  name                = "eh_ctf-vnet"
  resource_group_name = data.azurerm_resource_group.eh_ctf-rg.name
  location            = data.azurerm_resource_group.eh_ctf-rg.location
  address_space       = ["10.0.0.0/8"]
}

# Create a subnet within the virtual network
resource "azurerm_subnet" "eh_ctf-subnet" {
  name                 = "eh_ctf-subnet"
  resource_group_name  = data.azurerm_resource_group.eh_ctf-rg.name
  virtual_network_name = azurerm_virtual_network.eh_ctf-vnet.name
  address_prefixes     = ["10.13.37.0/24"]
}

# Create a network security group for the subnet
resource "azurerm_network_security_group" "eh_ctf-nsg" {
  name                = "eh_ctf-nsg"
  location            = data.azurerm_resource_group.eh_ctf-rg.location
  resource_group_name = data.azurerm_resource_group.eh_ctf-rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = "${distinct(concat(var.ip-whitelist, [chomp(data.http.public-ip.body)]))}"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefixes    = var.ip-whitelist
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "RDP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = var.ip-whitelist
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Internal"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.13.37.0/24"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "eh_ctf-nsga" {
  subnet_id                 = azurerm_subnet.eh_ctf-subnet.id
  network_security_group_id = azurerm_network_security_group.eh_ctf-nsg.id
}

# Create a public IP address for the lab
resource "azurerm_public_ip" "eh_ctf-ip" {
  name                = "eh_ctf-ip"
  location            = data.azurerm_resource_group.eh_ctf-rg.location
  resource_group_name = data.azurerm_resource_group.eh_ctf-rg.name
  allocation_method   = "Static"
  domain_name_label   = var.domain-name-label
  sku                 = "Standard"
}

# Create another public IP address for outbound traffic
resource "azurerm_public_ip" "eh_ctf-ip-outbound" {
  name                = "eh_ctf-ip-outbound"
  location            = data.azurerm_resource_group.eh_ctf-rg.location
  resource_group_name = data.azurerm_resource_group.eh_ctf-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create a load balancer on the public IP
resource "azurerm_lb" "eh_ctf-lb" {
  name                = "eh_ctf-lb"
  location            = data.azurerm_resource_group.eh_ctf-rg.location
  resource_group_name = data.azurerm_resource_group.eh_ctf-rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "eh_ctf-lb-ip-public"
    public_ip_address_id = azurerm_public_ip.eh_ctf-ip.id
  }
}

resource "azurerm_lb_nat_rule" "eh_ctf-lb-nat-http" {
  resource_group_name            = data.azurerm_resource_group.eh_ctf-rg.name
  loadbalancer_id                = azurerm_lb.eh_ctf-lb.id
  name                           = "HTTPAccess"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "eh_ctf-lb-ip-public"
}

resource "azurerm_lb_nat_rule" "eh_ctf-lb-nat-ssh" {
  resource_group_name            = data.azurerm_resource_group.eh_ctf-rg.name
  loadbalancer_id                = azurerm_lb.eh_ctf-lb.id
  name                           = "SSHAccess"
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
  frontend_ip_configuration_name = "eh_ctf-lb-ip-public"
}

resource "azurerm_lb_nat_rule" "eh_ctf-lb-nat-rdp" {
  resource_group_name            = data.azurerm_resource_group.eh_ctf-rg.name
  loadbalancer_id                = azurerm_lb.eh_ctf-lb.id
  name                           = "RDPAccess"
  protocol                       = "Tcp"
  frontend_port                  = 3389
  backend_port                   = 3389
  frontend_ip_configuration_name = "eh_ctf-lb-ip-public"
}

# Create NAT gateway for outbound internet access
resource "azurerm_nat_gateway" "eh_ctf-nat-gateway" {
  name                    = "eh_ctf-nat-gateway"
  location                = data.azurerm_resource_group.eh_ctf-rg.location
  resource_group_name     = data.azurerm_resource_group.eh_ctf-rg.name
}

resource "azurerm_nat_gateway_public_ip_association" "eh_ctf-nat-gateway-ip" {
  nat_gateway_id       = azurerm_nat_gateway.eh_ctf-nat-gateway.id
  public_ip_address_id = azurerm_public_ip.eh_ctf-ip-outbound.id
}

resource "azurerm_subnet_nat_gateway_association" "eh_ctf-nat-gateway-subnet" {
  subnet_id      = azurerm_subnet.eh_ctf-subnet.id
  nat_gateway_id = azurerm_nat_gateway.eh_ctf-nat-gateway.id
}
