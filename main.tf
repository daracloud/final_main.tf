resource "aws_vpc" "my_vpc" {
  cidr_block       = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "My VPC"
  }
}

resource "aws_subnet" "public_us_east_1a" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Public Subnet us-east-1a"
  }
}

resource "aws_subnet" "public_us_east_1b" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Public Subnet us-east-1b"
  }
}

resource "aws_internet_gateway" "my_vpc_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "My VPC - Internet Gateway"
  }
}

resource "aws_route_table" "my_vpc_public" {
    vpc_id = aws_vpc.my_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my_vpc_igw.id
    }

    tags = {
        Name = "Public Subnets Route Table for My VPC"
    }
}

resource "aws_route_table_association" "my_vpc_us_east_1a_public" {
    subnet_id = aws_subnet.public_us_east_1a.id
    route_table_id = aws_route_table.my_vpc_public.id
}

resource "aws_route_table_association" "my_vpc_us_east_1b_public" {
    subnet_id = aws_subnet.public_us_east_1b.id
    route_table_id = aws_route_table.my_vpc_public.id
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound connections"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP Security Group"
  }
}

# Create web instance
resource "aws_launch_configuration" "web" {
  name_prefix = "web-"

  image_id = "ami-0947d2ba12ee1ff75" # Amazon Linux 2 AMI (HVM), SSD Volume Type
  instance_type = "t2.micro"
  key_name = "Lenovo T410"

  security_groups = [ aws_security_group.allow_http.id ]
  associate_public_ip_address = true

  user_data = < /usr/share/nginx/html/index.html
chkconfig nginx on
service nginx start
  USER_DATA

  lifecycle {
    create_before_destroy = true
  }
}

# Create load balancer


AWS, TERRAFORM
TERRAFORM – MANAGING AUTO SCALING GROUPS & LOAD BALANCERS
Andrei Maksimov
Andrei Maksimov
March 16, 2021
No Comments
5(2)
Table of contents
Update: 2020 Oct
Auto Scaling Groups
Setting up VPC.
Launch configuration
Load balancer
Auto scaling group
Auto scaling policies
Summary
Related articles
This article continues the Terraform article series and covers how to use Terraform to create AutoScaling Groups in AWS cloud – a collection of EC2 instances that share similar characteristics and are treated as a logical grouping, such as scaling and management.

Update: 2020 Oct
Terraform code updated to support newer syntax.

As soon as you learn how to manage basic network infrastructure in AWS using Terraform (see “Terraform recipe – Managing AWS VPC – Creating Public Subnet” and “Terraform recipe – Managing AWS VPC – Creating Private Subnets”), you want to start creating auto-scalable infrastructures.

Auto Scaling Groups
Usually, Auto Scaling Groups are used to control the number of instances executing the same task like rendering dynamic web pages for your website, decoding videos and images, or calculating machine learning models.

Auto Scaling Groups also allows you to dynamically control your server pool size – increase it when your web servers are processing more traffic or tasks than usual, or decrease it when it becomes quieter.

In any case, this feature allows you to save your budget and make your infrastructure more fault-tolerant significantly.

Let’s build a simple infrastructure, which consists of several web servers for serving website traffic. In the following article, we’ll add RDS DB to our infrastructure.

Our infrastructure will be the following:


You may find complete .tf file source code in my GitHub repository.

Setting up VPC.
Let’s assemble it in a new infrastructure.tf file. First of all, let’s declare VPC, two Public Subnets, Internet Gateway and Route Table (we may take this example as a base):

resource "aws_vpc" "my_vpc" {
  cidr_block       = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "My VPC"
  }
}

resource "aws_subnet" "public_us_east_1a" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Public Subnet us-east-1a"
  }
}

resource "aws_subnet" "public_us_east_1b" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Public Subnet us-east-1b"
  }
}

resource "aws_internet_gateway" "my_vpc_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "My VPC - Internet Gateway"
  }
}

resource "aws_route_table" "my_vpc_public" {
    vpc_id = aws_vpc.my_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my_vpc_igw.id
    }

    tags = {
        Name = "Public Subnets Route Table for My VPC"
    }
}

resource "aws_route_table_association" "my_vpc_us_east_1a_public" {
    subnet_id = aws_subnet.public_us_east_1a.id
    route_table_id = aws_route_table.my_vpc_public.id
}

resource "aws_route_table_association" "my_vpc_us_east_1b_public" {
    subnet_id = aws_subnet.public_us_east_1b.id
    route_table_id = aws_route_table.my_vpc_public.id
Everything here should be very similar for you. If not, I strongly recommend you to spend some time on the “Terraform recipe – Managing AWS VPC – Creating Public Subnet” and “Terraform recipe – Managing AWS VPC – Creating Private Subnets” articles.

Next, we need to describe the Security Group for our web-servers, which will allow HTTP connections to our instances:

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound connections"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP Security Group"
  }
Launch configuration
As soon as we have SecurityGroup, we may describe a Launch Configuration. Think of it like a template containing all instance settings to apply to each new launched by Auto Scaling Group instance. We’re using aws_launch_configuration resource in Terraform to describe it

Most of the parameters should be familiar to you, as we already used them in aws_instance resource.

resource "aws_launch_configuration" "web" {
  name_prefix = "web-"

  image_id = "ami-0947d2ba12ee1ff75" # Amazon Linux 2 AMI (HVM), SSD Volume Type
  instance_type = "t2.micro"
  key_name = "Lenovo T410"

  security_groups = [ aws_security_group.allow_http.id ]
  associate_public_ip_address = true

  user_data = < /usr/share/nginx/html/index.html
chkconfig nginx on
service nginx start
  USER_DATA

  lifecycle {
    create_before_destroy = true
  }
}
The new ones are a user_data and a lifecycle:

user_data – is a special interface created by AWS for EC2 instances automation. Usually this option is filled with scripted instructions to the instance, which need to be executed at the instance boot time. For most of the OS this is done by cloud-init.
lifecycle – special instruction, which is declaring how new launch configuration rules applied during update. We’re using create_before_destroy here to create new instances from a new launch configuration before destroying the old ones. This option commonly used during rolling deployments.
The user-data option is filled with a simple bash-script, which installs the Nginx web server and puts the instance’s local IP address to the index.html file, so we can see it after the instance is up and running.

Load balancer
Before we create an Auto Scaling Group, we need to declare a Load Balancer. There are three Load Balances available for you in AWS right now:

Elastic or Classic Load Balancer (ELB) – previous generation of Load Balancers in AWS.
Application Load Balancer (ALB) – operates on application network layer and provides reach feature set to manage HTTP and HTTPS traffic for your web applications.
Network Load Balancer (NLB) – operates on connection layer and capable for handling millions of requests per second.
For simplicity, let’s create an Elastic Load Balancer in front of our EC2 instances (I’ll show how to use other types of them in future articles). To do that, we need to declare aws_elb resource.

resource "aws_security_group" "elb_http" {
  name        = "elb_http"
  description = "Allow HTTP traffic to instances through Elastic Load Balancer"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP through ELB Security Group"
  }
}

resource "aws_elb" "web_elb" {
  name = "web-elb"
  security_groups = [
    aws_security_group.elb_http.id
  ]
  subnets = [
    aws_subnet.public_us_east_1a.id,
    aws_subnet.public_us_east_1b.id
  ]

  cross_zone_load_balancing   = true

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:80/"
  }

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }

}
  
  #Create Autoscaling Group
  resource "aws_autoscaling_group" "web" {
  name = "${aws_launch_configuration.web.name}-asg"

  min_size             = 1
  desired_capacity     = 2
  max_size             = 4
  
  health_check_type    = "ELB"
  load_balancers = [
    aws_elb.web_elb.id
  ]

  launch_configuration = aws_launch_configuration.web.name

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"

  vpc_zone_identifier  = [
    aws_subnet.public_us_east_1a.id,
    aws_subnet.public_us_east_1b.id
  ]

  # Required to redeploy without an outage.
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "web"
    propagate_at_launch = true
  }

}
  
  output "elb_dns_name" {
  value = aws_elb.web_elb.dns_name
}
  
