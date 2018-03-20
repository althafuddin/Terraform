provider "aws" {
  access_key = "${var.AWS_ACCESS_KEY}"
  secret_key = "${var.AWS_SECRET_KEY}"
  region     = "${var.AWS_REGION}"
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  default     = 8080
}

# Creating Launch Configuration
resource "aws_launch_configuration" "Aws_launchconf" {
  image_id        = "ami-2d39803a"
  instance_type   = "t2.micro"
  security_groups = ["${aws_security_group.Aws_instance_sg.id}"]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World ! I am your server created from Terrafrom" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

# Adding Security Group For Instace
resource "aws_security_group" "Aws_instance_sg" {
  name = "Aws-securityGroup-EC2-tf"

  ingress {
    from_port   = "${var.server_port}"
    to_port     = "${var.server_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Creating Auto Scaling Group 
resource "aws_autoscaling_group" "Aws_ASG_TF" {
  launch_configuration = "${aws_launch_configuration.Aws_launchconf.id}"
  availability_zones   = ["${data.aws_availability_zones.all.names}"]
  min_size             = 2
  max_size             = 10

  load_balancers    = ["${aws_elb.Aws_elb.name}"]
  health_check_type = "ELB"

  tag {
    key                 = "Name"
    value               = "aws-asg-tf"
    propagate_at_launch = true
  }
}

# Fetching Availability Grops
data "aws_availability_zones" "all" {}

# Creating Load Balancer
resource "aws_elb" "Aws_elb" {
  name               = "Aws-elb-tf"
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "${var.server_port}"
    instance_protocol = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    target              = "HTTP:${var.server_port}/"
  }
}

# Adding Security Group For elb
resource "aws_security_group" "Aws_elb_sg" {
  name = "Aws-Elb-SG-tf"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Spit out the loadbalancer Name
output "elb_dns_name" {
  value = "${aws_elb.Aws_elb.dns_name}"
}
