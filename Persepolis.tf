provider "aws" {
  region = "us-east-1"
}

#VPC resources
resource "aws_vpc" "persepolis" {
  cidr_block       = "10.0.0.0/16"
}
resource "aws_subnet" "subnetA" {
  vpc_id     = "${aws_vpc.persepolis.id}"
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnetB" {
  vpc_id     = "${aws_vpc.persepolis.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnetC" {
  vpc_id     = "${aws_vpc.persepolis.id}"
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1c"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.persepolis.id}"
}

resource "aws_route" "r" {
  route_table_id            = "${aws_vpc.persepolis.main_route_table_id}"
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.gw.id}"
}

#
//resource "aws_cloudformation_stack" "backend" {
//  name = "persepolis"
//
//  parameters = {
//    VPCCidr = "10.0.0.0/16"
//  }
//
//  template_body = "${file("Persepolis.cform")}"
//}

#Autoscaling group

resource "aws_iam_instance_profile" "persepolis_profile" {
  name = "persepolis_profile"
  role = "${aws_iam_role.persepolis_role.name}"
}

resource "aws_iam_role" "persepolis_role" {
  name = "persepolis_role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": {
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }
}
EOF
}

resource "aws_iam_role_policy" "persepolis_policy" {
  name = "persepolis_policy"
  role = "${aws_iam_role.persepolis_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "firehose:*",
            "Resource": "arn:aws:firehose:*"
        }
    ]
}
EOF
}


resource "aws_key_pair" "persepolis-key" {
  key_name   = "persepolis-key"
  public_key = "${file("persepolis-key.pub")}"
}

resource "aws_launch_configuration" "persepolis_launch" {
  name_prefix   = "persepolis-"
  image_id      = "ami-02eac2c0129f6376b"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.persepolis-key.key_name}"
  user_data = "${file("persepolis-datapump.sh")}"
  security_groups = ["${aws_security_group.allow_ssh.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.persepolis_profile.id}"

  root_block_device {
    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "persepolis_autoscale" {
  name                 = "persepolis_autoscale"
  launch_configuration = "${aws_launch_configuration.persepolis_launch.name}"
  min_size             = 3
  max_size             = 5
  vpc_zone_identifier  = ["${aws_subnet.subnetA.id}", "${aws_subnet.subnetB.id}", "${aws_subnet.subnetC.id}"]
  depends_on = ["aws_internet_gateway.gw"]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = "${aws_vpc.persepolis.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

