variable "project_name" {
  description = "A unique name for the project to prefix resources."
  type        = string
  default     = "YOUR_LAB_NAME"
}

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "YOUR_PREFERRED REGION"
}

variable "key_pair_name" {
  description = "Name of an existing EC2 KeyPair to enable SSH access to the instances."
  type        = string
	default			= "YOUR_KEYPAIR_NAME"
}

variable "allowed_mgmt_cidr" {
  description = "The CIDR block of your management location for SSH/HTTPS access."
  type        = list(string)
  default     = ["0.0.0.0/0"] # For ease of lab use, but replace with your IP for production.
}

variable "admin_password" {
  description = "The initial admin password for the VM-Series firewall."
  type        = string
  sensitive   = true
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "mgmt_subnet_cidr" {
  description = "CIDR block for the Management (Public) subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "untrust_subnet_cidr" {
  description = "CIDR block for the Untrust (Public) subnet."
  type        = string
  default     = "10.0.2.0/24"
}

variable "trust_subnet_cidr" {
  description = "CIDR block for the Trust (Private) subnet."
  type        = string
  default     = "10.0.3.0/24"
}

variable "vm_series_instance_type" {
  description = "EC2 instance type for the VM-Series firewall."
  type        = string
  default     = "m5.xlarge"
}

variable "ubuntu_instance_type" {
  description = "EC2 instance type for the Ubuntu tester server."
  type        = string
  default     = "t3.micro"
}
