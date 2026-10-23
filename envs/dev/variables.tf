
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "subnet_id_a" {
  description = "First subnet (AZ-a) to use for instances"
  type        = string
}

variable "subnet_id_b" {
  description = "Second subnet (AZ-b) to use for instances"
  type        = string
}

variable "ami_al2023" {
  description = "AMI ID for Amazon Linux 2023"
  type        = string
}
