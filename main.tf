# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

################################################################################
# DATA SOURCES (AMIs)
################################################################################

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

data "aws_ami" "vmseries" {
  most_recent = true
  filter {
    name   = "product-code"
    values = ["6njl1pau431dv1qxipg63mvah"] # This is the BYOL product code
  }
  owners = ["679593333241"] # Palo Alto Networks
}

################################################################################
# NETWORKING (VPC, Subnets, IGW, EIPs)
################################################################################

resource "aws_vpc" "lab_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.project_name}-VPC"
  }
}

resource "aws_internet_gateway" "lab_igw" {
  vpc_id = aws_vpc.lab_vpc.id
  tags = {
    Name = "${var.project_name}-IGW"
  }
}

# Subnets
resource "aws_subnet" "mgmt_subnet" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = var.mgmt_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project_name}-Mgmt-Subnet"
  }
}

resource "aws_subnet" "untrust_subnet" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = var.untrust_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project_name}-Untrust-Subnet"
  }
}

resource "aws_subnet" "trust_subnet" {
  vpc_id            = aws_vpc.lab_vpc.id
  cidr_block        = var.trust_subnet_cidr
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "${var.project_name}-Trust-Subnet"
  }
}

# Elastic IPs
resource "aws_eip" "mgmt_eip" {
  domain = "vpc"
  tags = {
    Name = "${var.project_name}-VMSeries-Mgmt-EIP"
  }
}

resource "aws_eip" "untrust_eip" {
  domain = "vpc"
  tags = {
    Name = "${var.project_name}-VMSeries-Untrust-EIP"
  }
}

################################################################################
# ROUTING
################################################################################

# Public Route Table for Mgmt and Untrust Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.lab_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab_igw.id
  }
  tags = {
    Name = "${var.project_name}-Public-RT"
  }
}

resource "aws_route_table_association" "mgmt_rt_assoc" {
  subnet_id      = aws_subnet.mgmt_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "untrust_rt_assoc" {
  subnet_id      = aws_subnet.untrust_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Table for the Trust Subnet
resource "aws_route_table" "trust_rt" {
  vpc_id = aws_vpc.lab_vpc.id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_network_interface.vmseries_trust.id # Route all traffic to the firewall's trust interface
  }
  tags = {
    Name = "${var.project_name}-Trust-RT"
  }
}

resource "aws_route_table_association" "trust_rt_assoc" {
  subnet_id      = aws_subnet.trust_subnet.id
  route_table_id = aws_route_table.trust_rt.id
}

# *** THE KEY FIX: Gateway Route Table for Ingress Routing ***
resource "aws_route_table" "gw_rt" {
  vpc_id = aws_vpc.lab_vpc.id
  tags = {
    Name = "${var.project_name}-Gateway-Ingress-RT"
  }
}

resource "aws_route" "gw_ingress_route" {
  route_table_id         = aws_route_table.gw_rt.id
  destination_cidr_block = var.trust_subnet_cidr               # Traffic to the trust subnet...
  network_interface_id   = aws_network_interface.vmseries_untrust.id # ...must go to the firewall's untrust interface first.
}

resource "aws_main_route_table_association" "a" {
  vpc_id         = aws_vpc.lab_vpc.id
  route_table_id = aws_route_table.gw_rt.id
}


################################################################################
# SECURITY GROUPS
################################################################################

resource "aws_security_group" "mgmt_sg" {
  name        = "${var.project_name}-Mgmt-SG"
  description = "Allow SSH/HTTPS for management"
  vpc_id      = aws_vpc.lab_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_mgmt_cidr
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_mgmt_cidr
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}-Mgmt-SG"
  }
}

resource "aws_security_group" "untrust_sg" {
  name        = "${var.project_name}-Untrust-SG"
  description = "Allow all traffic to/from Untrust interface"
  vpc_id      = aws_vpc.lab_vpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}-Untrust-SG"
  }
}

resource "aws_security_group" "trust_sg" {
  name        = "${var.project_name}-Trust-SG"
  description = "Allow all traffic within the Trust zone"
  vpc_id      = aws_vpc.lab_vpc.id
  
  # Allow all traffic from other members of this same security group
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}-Trust-SG"
  }
}

################################################################################
# EC2 INSTANCES & INTERFACES
################################################################################

# --- Network Interfaces for VM-Series ---
resource "aws_network_interface" "vmseries_mgmt" {
  subnet_id       = aws_subnet.mgmt_subnet.id
  security_groups = [aws_security_group.mgmt_sg.id]
  tags = {
    Name = "${var.project_name}-VMSeries-eth0-Mgmt"
  }
}

resource "aws_network_interface" "vmseries_untrust" {
  subnet_id         = aws_subnet.untrust_subnet.id
  security_groups   = [aws_security_group.untrust_sg.id]
  source_dest_check = false
  tags = {
    Name = "${var.project_name}-VMSeries-eth1-Untrust"
  }
}

resource "aws_network_interface" "vmseries_trust" {
  subnet_id         = aws_subnet.trust_subnet.id
  security_groups   = [aws_security_group.trust_sg.id]
  source_dest_check = false
  tags = {
    Name = "${var.project_name}-VMSeries-eth2-Trust"
  }
}


# --- EIP Associations ---
resource "aws_eip_association" "mgmt_eip_assoc" {
  network_interface_id = aws_network_interface.vmseries_mgmt.id
  allocation_id        = aws_eip.mgmt_eip.id
}

resource "aws_eip_association" "untrust_eip_assoc" {
  network_interface_id = aws_network_interface.vmseries_untrust.id
  allocation_id        = aws_eip.untrust_eip.id
}


# --- VM-Series Firewall Instance ---
resource "aws_instance" "vmseries" {
  ami                   = data.aws_ami.vmseries.id
  instance_type         = var.vm_series_instance_type
  key_name              = var.key_pair_name

  network_interface {
    network_interface_id = aws_network_interface.vmseries_mgmt.id
    device_index         = 0
  }
  network_interface {
    network_interface_id = aws_network_interface.vmseries_untrust.id
    device_index         = 1
  }
  network_interface {
    network_interface_id = aws_network_interface.vmseries_trust.id
    device_index         = 2
  }

  tags = {
    Name = "${var.project_name}-VMSeries"
  }

}


# --- Ubuntu Test Instance ---
resource "aws_instance" "ubuntu_tester" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.ubuntu_instance_type
  key_name                    = var.key_pair_name
  subnet_id                   = aws_subnet.trust_subnet.id
  vpc_security_group_ids      = [aws_security_group.trust_sg.id]
  associate_public_ip_address = false

  tags = {
    Name = "${var.project_name}-Ubuntu-Tester"
  }

  depends_on = [aws_instance.vmseries]
}
