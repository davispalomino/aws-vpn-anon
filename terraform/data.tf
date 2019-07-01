#############
# ID Client #
#############
data "aws_caller_identity" "current" {}
#######################
# Search AMI-instance #
#######################
data "aws_ami" "this" {
  most_recent = true
  owners = ["${data.aws_caller_identity.current.account_id}"]

  filter {
    name   = "name"
    values = ["${var.owner}-${var.project}-*",]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

####################
# Search AZ-Subnet #
####################
data "aws_subnet" "this" {
  id = "${var.subnet}"
}

######################
# Capture Price Spot #
######################
data "local_file" "spot-ec2" {
  filename = "${path.module}/spot.info"
  depends_on = ["null_resource.spot-ec2"]
}
