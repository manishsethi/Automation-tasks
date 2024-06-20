# main.tf
provider "aws" {
  region = "eu-west-2"
}

terraform {
  backend "s3" {
    bucket = "saas-terraform-config-stg"
    key    = "stg/terraform.tfstate"
    region = "eu-west-2"
  }
}

# Create VPC creation
module "my_vpc" {
  source         = "./modules/vpc"
  vpc_cidr_block = "10.0.0.0/16"
  vpc_name       = "saas-stg-vpc"
}




# Create RDS PostgreSQL instance

resource "aws_security_group" "rds_new_security_group" {
  name        = "rds-new-security-group"
  description = "Security group for RDS allowing port 5432 from VPC CIDR"
  vpc_id      = module.my_vpc.vpc_id # Assuming you have access to the VPC ID from your module

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Replace with your VPC CIDR range
  }
}

module "my_rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.7.0"

  db_subnet_group_name   = module.my_vpc.default_db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds_new_security_group.id]

  engine             = "postgres"
  engine_version     = "16.1"
  instance_class     = "db.t3.micro"
  allocated_storage  = 20
  identifier         = "saas-stg-db"
  db_name            = "mydatabase"
  username           = "saas"
  maintenance_window = "Mon:03:00-Mon:04:00"
  port               = 5432
  backup_window      = "09:00-10:00"
  family             = "postgres16"
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "saas-cluster"
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

data "aws_secretsmanager_secret" "rds_master_user_secret" {
  arn = module.my_rds.db_instance_master_user_secret_arn
}

data "aws_secretsmanager_secret_version" "rds_master_user_secret_version" {
  secret_id = data.aws_secretsmanager_secret.rds_master_user_secret.id
}

data "template_file" "rds_secret_template" {
  template = data.aws_secretsmanager_secret_version.rds_master_user_secret_version.secret_string
}

locals {
  parsed_secret = jsondecode(data.template_file.rds_secret_template.rendered)
}

# Policy for ECS execution role.
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "nextjs" {
  family                   = "nextjs-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "nextjs-app"
      image     = "851725457605.dkr.ecr.eu-west-2.amazonaws.com/nextjs-app:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ],
      environment = [
        {
          name  = "DB_HOST"
          value = module.my_rds.db_instance_endpoint
        },
        {
          name  = "DB_NAME"
          value = "mydatabase"
        },
        {
          name  = "DB_USER"
          value = "saas"
        },
        {
          name  = "DB_PASSWORD"
          value = local.parsed_secret.password
        },
        {
          name  = "DATABASE_URL"
          value = "postgres://saas:${local.parsed_secret.password}@${module.my_rds.db_instance_endpoint}/mydatabase"
        }
      ]
    }
  ])

  depends_on = [module.my_rds]
}

# Security Group for ECS task
resource "aws_security_group" "ecs_task_security_group" {
  name        = "ecs-task-security-group"
  description = "Security group for ECS task allowing inbound 3000 and all outbound traffic"
  vpc_id      = module.my_vpc.vpc_id # Replace with your VPC ID

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow inbound traffic from any source on port 3000
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound traffic to any destination
  }
}

# Security Group for Loadbalancer
resource "aws_security_group" "loadbalancer_task_security_group" {
  name        = "loadbalancer-task-security-group"
  description = "Security group for ECS load balancer task allowing inbound 80 and all outbound traffic"
  vpc_id      = module.my_vpc.vpc_id # Replace with your VPC ID

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow inbound traffic on port 80 from any source
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound traffic to any destination
  }
}


# ECS Service
resource "aws_ecs_service" "nextjs" {
  name            = "nextjs-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.nextjs.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.my_vpc.private_subnet_ids
    security_groups  = [aws_security_group.ecs_task_security_group.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.nextjs.arn
    container_name   = "nextjs-app"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.nextjs,aws_ecs_task_definition.nextjs]
}

# Application Load Balancer (ALB)
resource "aws_lb" "nextjs" {
  name               = "nextjs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.loadbalancer_task_security_group.id]
  subnets            = module.my_vpc.public_subnet_ids
}

resource "aws_lb_target_group" "nextjs" {
  name        = "nextjs-targets"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = module.my_vpc.vpc_id
  target_type = "ip"
}

resource "aws_lb_listener" "nextjs" {
  load_balancer_arn = aws_lb.nextjs.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nextjs.arn
  }
}

# Output variables
output "ecs_cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "alb_dns_name" {
  value = aws_lb.nextjs.dns_name
}