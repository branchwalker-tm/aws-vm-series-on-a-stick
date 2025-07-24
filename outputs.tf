# outputs.tf

################################################################################
# Password and auth code
################################################################################

output "admin_password" {
	description = "The password entered by the user."
	value				= var.admin_password
	sensitive  	= true
}

output "auth_code" {
	description = "The auth code entered by the user."
	value 			= var.vmseries_auth_code
	sensitive 	= true
}

output "key_pair_name" {
	description = "The key pair name from variables.tf"
	value				= var.key_pair_name
}

################################################################################
# Network CIDR Outputs
################################################################################

output "vpc_cidr" {
  description = "The CIDR block of the VPC."
  value       = aws_vpc.lab_vpc.cidr_block
}

output "mgmt_subnet_cidr" {
  description = "The CIDR block of the Management subnet."
  value       = aws_subnet.mgmt_subnet.cidr_block
}

output "untrust_subnet_cidr" {
  description = "The CIDR block of the Untrust subnet."
  value       = aws_subnet.untrust_subnet.cidr_block
}

output "trust_subnet_cidr" {
  description = "The CIDR block of the Trust subnet."
  value       = aws_subnet.trust_subnet.cidr_block
}

################################################################################
# VM-Series Firewall IP Outputs
################################################################################

output "vmseries_mgmt_public_ip" {
  description = "Public IP address for the VM-Series Management interface."
  value       = aws_eip.mgmt_eip.public_ip
}

output "vmseries_mgmt_private_ip" {
  description = "Private IP address for the VM-Series Management interface."
  value       = aws_network_interface.vmseries_mgmt.private_ip
}

output "vmseries_untrust_public_ip" {
  description = "Public IP address for the VM-Series Untrust interface."
  value       = aws_eip.untrust_eip.public_ip
}

output "vmseries_untrust_private_ip" {
  description = "Private IP address for the VM-Series Untrust interface."
  value       = aws_network_interface.vmseries_untrust.private_ip
}

output "vmseries_trust_private_ip" {
  description = "Private IP address for the VM-Series Trust interface."
  value       = aws_network_interface.vmseries_trust.private_ip
}

################################################################################
# Test Instance IP Outputs
################################################################################

output "ubuntu_tester_private_ip" {
  description = "Private IP address of the Ubuntu test instance."
  value       = aws_instance.ubuntu_tester.private_ip
}
