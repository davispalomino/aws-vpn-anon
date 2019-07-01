######################
# AWS-CLI exec price #
######################
resource "null_resource" "spot-ec2" {
  triggers = {
        build_number = "${timestamp()}"
    }
  provisioner "local-exec" {
    command =<<EOT
        aws ec2 describe-spot-price-history --instance-types ${var.type_sec[var.type]} --start-time=$(date +%s) --product-descriptions="Linux/UNIX" --filter "Name=availability-zone,Values=${data.aws_subnet.this.availability_zone}" --query 'SpotPriceHistory[*].{price:SpotPrice}' --region ${var.region} --output text >${path.module}/spot.info
        EOT
  }
}