variable "region" {
  description = "AWS region"
  default     = "us-west-2"
}

variable "name_node_instance_type" {
  description = "EC2 instance type for NameNode"
  default     = "t3.medium"
}

variable "data_node_instance_type" {
  description = "EC2 instance type for DataNode"
  default     = "t3.medium"
}

variable "zookeeper_instance_type" {
  description = "EC2 instance type for Zookeeper"
  default     = "t3.medium"
}

variable "resource_manager_instance_type" {
  description = "EC2 instance type for ResourceManager"
  default     = "t3.medium"
}

variable "ami" {
  description = "AMI ID for EC2 instances"
  default     = "ami-0cf2b4e024cdb6960"
}

variable "key_name" {
  description = "Key pair name for EC2 instances"
  default     = "ms-key"
}
