terraform {
  backend "s3" {
    bucket         = "ha-cluster-terraform"
    key            = "dev/terraform-ha-cluster.tfstate"
    region         = "us-west-2"
  }
}

provider "aws"{
  region = var.region
}

# Create VPC creation
module "vpc" {
  source         = "./vpc-module/"
  vpc_cidr_block = "10.0.0.0/16"
  vpc_name       = "hadoop-stg-vpc"
}


resource "aws_instance" "name_node" {
  count          = 1
  ami            = var.ami
  instance_type  = var.name_node_instance_type
  key_name       = var.key_name
  subnet_id      = element(module.vpc.public_subnet_ids, count.index % length(module.vpc.public_subnet_ids))
  security_groups = [module.vpc.namenode_sg_id]
  tags = {
    Name = "NameNode"
  }
  root_block_device {
    volume_size = 30  # Increase volume size to 30 GB
    volume_type = "gp2"  # General Purpose SSD (gp2) is the default type
    delete_on_termination = true  # This is the default behavior
  }
}

resource "aws_instance" "data_node" {
  count          = 1
  ami            = var.ami
  instance_type  = var.data_node_instance_type
  key_name       = var.key_name
  subnet_id      = element(module.vpc.private_subnet_ids, count.index % length(module.vpc.private_subnet_ids))
  security_groups = [module.vpc.datanode_sg_id]
  tags = {
    Name = "DataNode"
  }
  root_block_device {
    volume_size = 30  # Increase volume size to 30 GB
    volume_type = "gp2"  # General Purpose SSD (gp2) is the default type
    delete_on_termination = true  # This is the default behavior
  }
}

resource "aws_instance" "zookeeper" {
  count          = 2
  ami            = var.ami
  instance_type  = var.zookeeper_instance_type
  key_name       = var.key_name
  subnet_id      = element(module.vpc.private_subnet_ids, count.index % length(module.vpc.private_subnet_ids))
  security_groups = [module.vpc.zookeeper_sg_id]
  tags = {
    Name = "Zookeeper"
  }
  root_block_device {
    volume_size = 30  # Increase volume size to 30 GB
    volume_type = "gp2"  # General Purpose SSD (gp2) is the default type
    delete_on_termination = true  # This is the default behavior
  }
}

resource "aws_instance" "resource_manager" {
  count          = 1
  ami            = var.ami
  instance_type  = var.resource_manager_instance_type
  key_name       = var.key_name
  subnet_id      = element(module.vpc.public_subnet_ids, count.index % length(module.vpc.public_subnet_ids))
  security_groups = [module.vpc.resource_manager_sg_id]
  tags = {
    Name = "ResourceManager"
  }
  root_block_device {
    volume_size = 30  # Increase volume size to 30 GB
    volume_type = "gp2"  # General Purpose SSD (gp2) is the default type
    delete_on_termination = true  # This is the default behavior
  }
}

output "name_node_ips" {
  value = aws_instance.name_node.*.public_ip
}

output "data_node_ips" {
  value = aws_instance.data_node.*.public_ip
}

output "zookeeper_ips" {
  value = aws_instance.zookeeper.*.public_ip
}

output "resource_manager_ips" {
  value = aws_instance.resource_manager.*.public_ip
}

output "generate_inventory" {
  value = join("\n", [
    "[namenodes]",
    join("\n", aws_instance.name_node.*.private_ip),
    "",
    "[datanodes]",
    join("\n", aws_instance.data_node.*.private_ip),
    "",
    "[zookeepers]",
    join("\n", aws_instance.zookeeper.*.private_ip),
    "",
    "[resourcemanagers]",
    join("\n", aws_instance.resource_manager.*.private_ip)
  ])
}

resource "null_resource" "generate_inventory" {
  provisioner "local-exec" {
    command = <<EOT
    echo "${join("\n", [
      "[namenodes]",
      join("\n", aws_instance.name_node.*.private_ip),
      "",
      "[datanodes]",
      join("\n", aws_instance.data_node.*.private_ip),
      "",
      "[zookeepers]",
      join("\n", aws_instance.zookeeper.*.private_ip),
      "",
      "[resourcemanagers]",
      join("\n", aws_instance.resource_manager.*.private_ip),
      "",
      "[all:vars]",
      "ansible_user=ubuntu",
      "ansible_ssh_private_key_file=ms-key.pem"
    ])}" > inventory.ini
    EOT
  }
}