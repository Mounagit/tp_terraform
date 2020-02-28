resource "azurerm_resource_group" "rg"{
	name= "${var.name}"
	location= "${var.location}"
	tags = {
		owner = "${var.owner}"
	}
}

resource "azurerm_virtual_network" "myFirstVnet" {
	name = "${var.name_vnet}"
	address_space = "${var.adress_space}"
	location = "${var.location}"
	resource_group_name = "${azurerm_resource_group.rg.name}"
}

#créer un subnet
resource "azurerm_subnet" "myFirstSubnet" {
	name= "${var.name_subnet}"
	resource_group_name= "${azurerm_resource_group.rg.name}"
	virtual_network_name= "${azurerm_virtual_network.myFirstVnet.name}"
	address_prefix= "${var.address_prefix}"
}   

#creation de security group
resource "azurerm_network_security_group" "myFirstnsg" {
name="${var.nameNsg}"
location="${var.location}"
resource_group_name="${azurerm_resource_group.rg.name}"

security_rule{
  name="SSH"
  priority=1001
  direction="Inbound"
  access="Allow"
  protocol="Tcp"
  source_port_range="*"
  destination_port_range="22"
  source_address_prefix="*"
  destination_address_prefix="*"
 }

security_rule{
  name="HTTP"
  priority=1002
  direction="Inbound"
  access="Allow"
  protocol="Tcp"
  source_port_range="*"
  destination_port_range="80"
  source_address_prefix="*"
  destination_address_prefix="*"
 }


}

#creation d'une IP public

resource "azurerm_public_ip" "myFirstPubIp" {
  name="${var.nameIpPub}"
  location="${var.location}"
  resource_group_name="${azurerm_resource_group.rg.name}"
  allocation_method="${var.allocation_method}"

 }

resource "azurerm_network_interface" "myFirstNIC" { 
 name="${var.nameNIC}"
 location="${var.location}"
 resource_group_name="${azurerm_resource_group.rg.name}" 
 network_security_group_id=""
 ip_configuration{
   name="${var.nameNICConfig}"
   subnet_id="${azurerm_subnet.myFirstSubnet.id}"
   private_ip_address_allocation="${var.allocation_method}"
   public_ip_address_id="${azurerm_public_ip.myFirstPubIp.id}"

 }

}

#creation d'une machine virtuelle

  
resource "azurerm_virtual_machine" "MyfirstVm" {
  name="${var.nameVM}"
  location="${var.location}"
  resource_group_name="${azurerm_resource_group.rg.name}"
  network_interface_ids=["${azurerm_network_interface.myFirstNIC.id}"]
  vm_size="${var.vmSize}"
  
  storage_os_disk {
    name="myDisk"
    caching="ReadWrite"
    create_option="FromImage"
    managed_disk_type="Standard_LRS"
 }

  storage_image_reference {
    publisher="OpenLogic"
    offer="CentOs"
    sku="7.6"
    version="latest" 
 }

  os_profile {
     computer_name  = "testMouna"                                                                    
     admin_username = "Mouni" 
 }

  os_profile_linux_config {
    disable_password_authentication= true

    ssh_keys {
      path="/home/mouna/.ssh/authorized_keys"
      key_data="${var.key_data}"
  }

 }
}


resource "azurerm_lb" "test" {
 name                = "loadBalancer"
 location            = "${var.location}"
 resource_group_name = "${azurerm_resource_group.rg.name}"

 frontend_ip_configuration {
   name                 = "publicIPAddress"
   public_ip_address_id = "${azurerm_public_ip.myFirstPubIp.id}"
 }
}

resource "azurerm_lb_backend_address_pool" "test" {
 resource_group_name = "${azurerm_resource_group.rg.name}"
 loadbalancer_id     = "${azurerm_lb.test.id}"
 name                = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "vmss" {
 resource_group_name = "${azurerm_resource_group.rg.name}"
 loadbalancer_id     = "${azurerm_lb.test.id}"
 name                = "ssh-running-probe"
 port                = "22"
}

resource "azurerm_lb_rule" "lbnatrule" {
   resource_group_name            = "${azurerm_resource_group.rg.name}"
   loadbalancer_id                = "${azurerm_lb.test.id}"
   name                           = "SSH"
   protocol                       = "Tcp"
   frontend_port                  = "22"
   backend_port                   = "22"
   backend_address_pool_id        = "${azurerm_lb_backend_address_pool.test.id}"
   frontend_ip_configuration_name = "publicIPAddress"
   probe_id                       = "${azurerm_lb_probe.vmss.id}"
}




resource "azurerm_network_interface" "test" {
 count               = 2
 name                = "nameNIC${count.index}"
 location            = "${var.location}"
 resource_group_name = "${azurerm_resource_group.rg.name}"

 ip_configuration {
   name                          = "nameNICConfig"
   subnet_id                     = "${azurerm_subnet.myFirstSubnet.id}"
   private_ip_address_allocation = "Dynamic"
   load_balancer_backend_address_pools_ids =["${azurerm_lb_backend_address_pool.test.id}"]
 }

}


resource "azurerm_availability_set" "avset" {
 name                         = "avset"
 location                     = "${var.location}"
 resource_group_name          = "${azurerm_resource_group.rg.name}"
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
 managed                      = true
}

resource "azurerm_virtual_machine" "myFirstVm" {
 count                 = 2
 name                  = "${var.nameVM}.${count.index}"
 location              = "${var.location}"
 availability_set_id   = "${azurerm_availability_set.avset.id}"
 resource_group_name   = "${azurerm_resource_group.rg.name}"
 network_interface_ids = ["${element(azurerm_network_interface.test.*.id, count.index)}"]
 vm_size               = "${var.vmSize}"




storage_image_reference {
   publisher = "Canonical"
   offer     = "UbuntuServer"
   sku       = "16.04-LTS"
   version   = "latest"
 }

 storage_os_disk {
   name              = "myosdisk.${count.index}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 os_profile {
   computer_name  = "testMouna"
   admin_username = "Mouni"
   
 }

 os_profile_linux_config {
   disable_password_authentication = true
   ssh_keys {
      path = "/home/Mouni/.ssh/authorized_keys"

      key_data = "${var.key_data}"
    }

   }
}
