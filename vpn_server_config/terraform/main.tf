terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 3.27"
        }
    }

    required_version = ">= 0.14.9"
}

provider "aws" {
    region = "eu-west-1"
}

# Create Key Pair

resource "aws_key_pair" "deployer" {
    key_name = "Flemo_SSH"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAgB/sbxg+j1E89Rh3RND7jwwv0OAQOiF5veneSSPipFXG0F4gLwS33SlqOOLU2me+VYi9VYzQeMiH5FUivoU1YfNANnK2bos9njnjkLWOMLaDqI+uYbuPM0l7z1OcbQSUXxS3rDyvQIPAdE/qcB+/fx5DN4jHwnIDHfGQTUe2rRmlfLBetpxx009QcuPXyl+MEcGx/cnMjB7/mF0bzU1reVftgNyU86odegHDXYismVrsvId2VG+5GirwPFHBDv4oH6mSQ7wRXoFLQoJp/vxGDGgSVXHUYZ+S/yERCM9l5/hGj7AtdH+IH6nlt6GV6BOmDq5Kg8DZ38zubKgM/7W6nZjvt6bL3/tfqo/LbyjizSvYDSL5C1/Yna+JcclIN10RF73ZL4s8Y9nh/DT9spIQJihCG0bVn2x6FDjCe32XyeCLowFxlBES8NZ/aV1bWojjCAtIIbeSf6dFlr77BOtSavcDbKn1HNQhogReaYq95aKrf1ndW/5aiWpb58ttzfxQJqwXnz5V40kNjjgkzKAiV5mXvGEngAjX/T+1Y1k50GweGT6mYC4ccmGrAx+nFAMte9taOt7Uu/4jlK3IbUmKahg60ov0mzK70rldyPnKcUmBbXQcZcYXdEYjElP91ig4fBoJCdaKjC4pT8c22/+oGrcjSJ+ismDasnJhoZw5sJNsw== SSH_Flemo"
}

# Create Networking
# Create VPC
resource "aws_vpc" "test_vpc" {
    cidr_block = "172.16.0.0/16"

    tags = {
        Name = "Temp_Testing_VPC"
        Creator = "Terraform"
    }
}

# Create Internet Gateway Subnet
resource "aws_subnet" "igw_subnet" {
    vpc_id = aws_vpc.test_vpc.id

    cidr_block = "172.16.1.0/24"

    map_public_ip_on_launch = true

    tags = {
        Name = "IGW VPC Subnet"
        Creator = "Terraform"
        Role = "VPC_Subnet_IGW"
    }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.test_vpc.id

    tags = {
        Name = "IGW"
        Creator = "Terraform"
        Role = "Internet_Gateway"
    }

    depends_on = [aws_subnet.igw_subnet]
}

# Create Route Table for Internet Gateway
resource "aws_route_table" "igw_route_table" {
    vpc_id = aws_vpc.test_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    tags = {
        Name = "IGW Route Table"
        Creator = "Terraform"
        Role = "VPC_RT_IGW"
    }
}

# Associate Route table for Internet Gateway to Internet Gateway Subnet
resource "aws_route_table_association" "igw" {
    subnet_id = aws_subnet.igw_subnet.id
    route_table_id = aws_route_table.igw_route_table.id
}

# Create Security Group
resource "aws_security_group" "vpn_allow_ports" {
    name = "vpn_allow_ports"
    description = "Allow required ports for VPN server"
    vpc_id = aws_vpc.test_vpc.id

    ingress {
        description = "Allow SSH From Everywhere"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }

    ingress {
        description = "Allow WireGuard"
        from_port = 4443
        to_port = 4443
        protocol = "udp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }


    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_network_interface" "eth0" {
    subnet_id = aws_subnet.igw_subnet.id
    private_ips = ["172.16.1.10"]

    security_groups = [aws_security_group.vpn_allow_ports.id]

    tags = {
        Name = "Pivot_eth0_Interface"
    }
}

# Create AWS Instance

resource "aws_instance" "vpn_server" {
    ami = "ami-0a8e758f5e873d1c1"
    instance_type = "t2.micro"

    network_interface {
        network_interface_id = aws_network_interface.eth0.id
        device_index = 0
    }

    key_name = aws_key_pair.deployer.key_name

    tags = {
        Name = "Test WG_VPN Server"
        Role = "WG_VPN"
        OS = "Centos7"
        Creator = "Terraform"
    }
}
