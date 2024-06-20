resource "aws_vpc" "my_vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = var.vpc_name
  }
}

resource "aws_security_group" "default_security_group" {
  name        = "my-default-security-group"
  description = "Default security group for my VPC"
  vpc_id      = aws_vpc.my_vpc.id
  # Add any additional security group rules as needed
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_subnet" "private_subnets" {
  count                   = length(var.private_subnet_cidr_blocks)
  cidr_block              = var.private_subnet_cidr_blocks[count.index]
  vpc_id                  = aws_vpc.my_vpc.id
  availability_zone       = var.availability_zones[count.index % length(var.availability_zones)]
  map_public_ip_on_launch = false
  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_cidr_blocks)
  cidr_block              = var.public_subnet_cidr_blocks[count.index]
  vpc_id                  = aws_vpc.my_vpc.id
  availability_zone       = var.availability_zones[count.index % length(var.availability_zones)]
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "my_natgw" {
  allocation_id = aws_eip.my_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id # Assuming you have a public subnet
}

resource "aws_eip" "my_eip" {
  domain = "vpc"
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.my_natgw.id
  }
}

resource "aws_route_table_association" "private_subnet_associations" {
  count          = length(aws_subnet.private_subnets)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

resource "aws_route_table_association" "public_subnet_associations" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_db_subnet_group" "default" {
  name       = "my-db-subnet-group"
  subnet_ids = aws_subnet.private_subnets[*].id
  tags = {
    Name = "My DB Subnet Group"
  }
}

output "vpc_id" {
  value = aws_vpc.my_vpc.id
}

output "private_subnet_ids" {
  value = aws_subnet.private_subnets[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnets[*].id
}

output "default_security_group_id" {
  value = aws_security_group.default_security_group.id
}

output "default_db_subnet_group_name" {
  value = aws_db_subnet_group.default.name
}
