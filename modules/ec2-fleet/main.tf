
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
  required_version = ">= 1.5"
}

locals {
  fleet_instances = {
    for k, v in var.instances : k => v
    if k != var.prevent_destroy_instance
  }

  protected_instances = {
    for k, v in var.instances : k => v
    if k == var.prevent_destroy_instance
  }
}

resource "aws_instance" "fleet" {
  for_each = local.fleet_instances

  ami           = each.value.ami
  instance_type = each.value.instance_type
  key_name      = each.value.key_name
  subnet_id     = each.value.subnet_id

  root_block_device {
    volume_type           = each.value.root_volume_type
    volume_size           = each.value.root_volume_size
    delete_on_termination = true
  }

  tags = {
    Name        = each.key
    Environment = each.value.environment
    Owner       = each.value.owner
  }

  lifecycle {
    ignore_changes = [tags["LastModified"]]
  }
}

resource "aws_instance" "protected" {
  for_each = local.protected_instances

  ami           = each.value.ami
  instance_type = each.value.instance_type
  key_name      = each.value.key_name
  subnet_id     = each.value.subnet_id

  root_block_device {
    volume_type           = each.value.root_volume_type
    volume_size           = each.value.root_volume_size
    delete_on_termination = true
  }

  tags = {
    Name        = each.key
    Environment = each.value.environment
    Owner       = each.value.owner
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags["LastModified"]]
  }
}
