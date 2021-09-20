#
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


#<!--* freshness: { owner: 'ttaggart@google.com' reviewed: '2020-sep-21' } *-->


resource "aws_vpc" "iap" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name  = "iap-vpc"
  }
}

resource "aws_subnet" "iap" {
  vpc_id     = aws_vpc.iap.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name  = "iap-subnet"
  }
}

resource "aws_internet_gateway" "aws_vpc_igw" {
  vpc_id = aws_vpc.iap.id

  tags = {
    Name = "aws-vpc-igw"
  }
}

resource "aws_security_group" "allow_rfc1918" {
  name        = "allow_rfc1918"
  description = "Allow rfc1918 inbound traffic"
  vpc_id      = aws_vpc.iap.id

  ingress {
    description = "rfc1918 from VPC & Google"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "iap-sg"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "app" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.allow_rfc1918.id]
  subnet_id                   = aws_subnet.iap.id
  user_data = <<EOF
#! /bin/bash
sudo apt-get update && sudo apt-get -y install apache2
echo '<!doctype html><html><body><h1>Hello from your Beyond Corp enabled App!</h1></body></html>' > /var/www/html/index.html
sudo systemctl start apache2
sudo systemctl enable apache2
EOF

  tags   = {
    Name = "app"
  }
}


resource "aws_vpn_gateway" "aws_vpn_gw" {
  vpc_id          = aws_vpc.iap.id
  amazon_side_asn = "64512"
}

resource "aws_customer_gateway" "aws_cgw" {
  bgp_asn    = 65000
  ip_address = google_compute_address.gcp_vpn_ip.address
  type       = "ipsec.1"

  tags = {
    "Name" = "aws-customer-gw"
  }
}

resource "aws_default_route_table" "aws_vpc" {
  default_route_table_id = aws_vpc.iap.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.aws_vpc_igw.id
  }

  propagating_vgws = [
    aws_vpn_gateway.aws_vpn_gw.id,
  ]
}

resource "aws_vpn_connection" "aws_vpn_connection1" {
  vpn_gateway_id      = aws_vpn_gateway.aws_vpn_gw.id
  customer_gateway_id = aws_customer_gateway.aws_cgw.id
  type                = "ipsec.1"
  static_routes_only  = false
  tags = {
    "Name" = "aws-vpn-connection1"
  }
}

