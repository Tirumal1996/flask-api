# Variables
variable "fname" {
  type    = string
  default = "flask"
}

variable "aws_account" {
  type    = string
  default = "905418311316"
}

# VPC
resource "aws_vpc" "flask_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name        = "flask-vpc"
    Environment = "production"
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.flask_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name        = "flask-public-subnet"
    Environment = "production"
  }
}
# Public Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.flask_vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name        = "flask-private-subnet"
    Environment = "production"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "flask_igw" {
  vpc_id = aws_vpc.flask_vpc.id

  tags = {
    Name = "flask-igw"
  }
}

# Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.flask_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.flask_igw.id
  }

  tags = {
    Name = "flask-public-route-table"
  }
}

# Route Table Association
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Security Group
resource "aws_security_group" "flask_api_sg" {
  name_prefix = "${var.fname}-api-sg-"
  vpc_id      = aws_vpc.flask_vpc.id

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to all for testing; restrict in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.fname}-api-sg"
    Environment = "production"
  }
}

# Load Balancer
resource "aws_lb" "flask_api_nlb" {
  name               = "${var.fname}-api-nlb"
  load_balancer_type = "network"
  subnets            = [aws_subnet.public_subnet.id]
  security_groups    = [aws_security_group.flask_api_sg.id]

  tags = {
    Name = "${var.fname}-api-nlb"
  }
}

# Target Group
resource "aws_lb_target_group" "flask_api_tg" {
  name        = "${var.fname}-api-tg"
  port        = 5000
  protocol    = "TCP"
  vpc_id      = aws_vpc.flask_vpc.id
  target_type = "ip"

  health_check {
    protocol            = "HTTP"
    port                = "5000"
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.fname}-api-tg"
  }
}

# Listener
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.flask_api_nlb.arn
  port              = "5000"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask_api_tg.arn
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "flask_cluster" {
  name = "${var.fname}-cluster"

  tags = {
    Name = "${var.fname}-cluster"
  }
}

# IAM Policy for ECS Task Execution
data "aws_iam_policy" "ecs_task_execution_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json

  tags = {
    Name = "ecs-task-execution-role"
  }
}

data "aws_iam_policy_document" "ecs_task_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = data.aws_iam_policy.ecs_task_execution_role_policy.arn
}

# ECS Task Definition
resource "aws_ecs_task_definition" "flask_task_def" {
  family                   = "${var.fname}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      "name": "${var.fname}-api",
      "image": "${aws_ecr_repository.flask_ecr.repository_url}:latest", # Use the ECR repository URL
      "enableExecuteCommand": true,
      "cpu": 512,
      "memory": 1024,
      "portMappings": [
        {
          "containerPort": 5000,
          "hostPort": 5000
        }
      ],
      "essential": true,
      "healthCheck": {
        "Command": ["CMD-SHELL", "curl -f http://localhost:5000/health || exit 1"],
        "Interval": 30,
        "Timeout": 5,
        "Retries": 3,
        "StartPeriod": 60
      }
    }
  ])
}


# ECS Service
resource "aws_ecs_service" "flask_service" {
  name            = "${var.fname}-service"
  cluster         = aws_ecs_cluster.flask_cluster.id
  task_definition = aws_ecs_task_definition.flask_task_def.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.flask_api_tg.arn
    container_name   = "${var.fname}-api"
    container_port   = 5000
  }

  network_configuration {
    assign_public_ip = true
    subnets          = [aws_subnet.public_subnet.id]
    security_groups  = [aws_security_group.flask_api_sg.id]
  }

  depends_on = [aws_lb_listener.front_end]

  tags = {
    Name = "${var.fname}-service"
  }
}

# Create an AWS Elastic Container Registry (ECR)
resource "aws_ecr_repository" "flask_ecr" {
  name                 = "${var.fname}-api"
  image_tag_mutability = "MUTABLE" # Images can be updated with the same tag
  image_scanning_configuration {
    scan_on_push = true # Enable image scanning for vulnerabilities
  }

  tags = {
    Name        = "${var.fname}-ecr"
    Environment = "production"
    Project     = "flask-api"
  }
}

# Output ECR Repository URL
output "ecr_repository_url" {
  value = aws_ecr_repository.flask_ecr.repository_url
  description = "The URL of the ECR repository"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_ecr_access" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
