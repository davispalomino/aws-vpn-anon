variable "owner" {
  type = string
}
variable "project" {
  type = string
}

variable "region" {
  type      = string
  default   = "us-east-1"
}

variable "type" {
  type  = string
  default = "advance"
}

variable "type_sec" {
  type = map
  default = {
    "standar" = "t2.micro",
    "advance" = "t2.medium",
    "high"    = "m3.xlarge"
  }
}

variable "subnet" {
  type = string
  default= null
}

variable "port_tcp" {
  type = list
  default= ["22","500","1723"]
}
variable "port_udp" {
  type = list
  default= ["500","1701","1723","4500"]
}

