# Configure the Azure provider
provider "azurerm" {
  features {}
  subscription_id = ""
  tenant_id       = ""
}

# Create a Resource Group
resource "azurerm_resource_group" "sec-res-group" {
  name     = "securityResourceGrp"
  location = "East US"
}

# Create a Virtual Network
resource "azurerm_virtual_network" "security-vnet" {
  name                = "securityVNet"
  location            = azurerm_resource_group.sec-res-group.location
  resource_group_name = azurerm_resource_group.sec-res-group.name
  address_space       = ["10.0.0.0/16"]
}

# Create a Subnet
resource "azurerm_subnet" "sec-pub-sub" {
  name                 = "securityPubSubnet"
  resource_group_name  = azurerm_resource_group.sec-res-group.name
  virtual_network_name = azurerm_virtual_network.security-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create network security group
resource "azurerm_network_security_group" "harmony-sase-nsg" {
  name                = "harmony-sase-nsg"
  location            = azurerm_resource_group.sec-res-group.location
  resource_group_name = azurerm_resource_group.sec-res-group.name

  security_rule {
    name                       = "allow_all_tcp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate nsg to subnet
resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.sec-pub-sub.id
  network_security_group_id = azurerm_network_security_group.harmony-sase-nsg.id
}


# Create a Public IP
resource "azurerm_public_ip" "securityPubIP" {
  name                = "securityPubIP"
  location            = azurerm_resource_group.sec-res-group.location
  resource_group_name = azurerm_resource_group.sec-res-group.name
  allocation_method   = "Static"
}

# Create a Network Interface (NIC)
resource "azurerm_network_interface" "harmonySASENIC" {
  name                = "harmony-saseNIC"
  location            = azurerm_resource_group.sec-res-group.location
  resource_group_name = azurerm_resource_group.sec-res-group.name
  #subnet_id           = azurerm_subnet.sec-pub-sub.id
  #private_ip_address  = "10.0.1.4"

  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.securityPubIP.id
    subnet_id                     = azurerm_subnet.sec-pub-sub.id
  }
}

# Reference the public SSH key from your local machine
resource "azurerm_linux_virtual_machine" "harmonySASEconnector" {
  name                = "harmonySASEconnector"
  location            = azurerm_resource_group.sec-res-group.location
  resource_group_name = azurerm_resource_group.sec-res-group.name
  size                = "Standard_B1s"  # You can adjust the size for 2GB of RAM
  admin_username      = "azureuser"

  os_disk {
    name = "harmonySASE-os_disk"
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # Reference your SSH public key
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("C:/Users/username/.ssh/key")  # Update this path to your public key file
  }

  network_interface_ids = [azurerm_network_interface.harmonySASENIC.id]

  tags = {
    environment = "development"
  }

}

output "public_ip_address" {
    value = "${azurerm_public_ip.securityPubIP.ip_address}"
}
