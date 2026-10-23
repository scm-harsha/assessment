variable "instances" {
  type = map(object({
    ami              = string
    instance_type    = string
    key_name         = string
    root_volume_type = string
    root_volume_size = number
    subnet_id        = string
    environment      = string
    owner            = string
  }))
}

variable "prevent_destroy_instance" {
  type = string
}
