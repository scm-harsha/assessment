
module "ec2_fleet" {
  source = "../../modules/ec2-fleet"
  instances = {

    "web-server" = {
      ami              = var.ami_al2023
      instance_type    = "t3.micro"
      key_name         = "key-web"
      root_volume_type = "gp3"
      root_volume_size = 20
      subnet_id        = var.subnet_id_a
      environment      = "dev"
      owner            = "platform-team"
    }

    "app-server" = {
      ami              = var.ami_al2023
      instance_type    = "t3.medium"
      key_name         = "key-app"
      root_volume_type = "gp2"
      root_volume_size = 30
      subnet_id        = var.subnet_id_a
      environment      = "dev"
      owner            = "app-team"
    }

    "db-server" = {
      ami              = var.ami_al2023
      instance_type    = "m5.large"
      key_name         = "key-db"
      root_volume_type = "io2"
      root_volume_size = 100
      subnet_id        = var.subnet_id_b
      environment      = "dev"
      owner            = "dba-team"
    }

    "cache-server" = {
      ami              = var.ami_al2023
      instance_type    = "t2.medium"
      key_name         = "key-cache"
      root_volume_type = "gp3"
      root_volume_size = 50
      subnet_id        = var.subnet_id_b
      environment      = "dev"
      owner            = "platform-team"
    }

    "bastion" = {
      ami              = var.ami_al2023
      instance_type    = "t3.nano"
      key_name         = "key-bastion"
      root_volume_type = "io1"
      root_volume_size = 8
      subnet_id        = var.subnet_id_a
      environment      = "dev"
      owner            = "security-team"
    }
  }

  prevent_destroy_instance = "db-server"
}
