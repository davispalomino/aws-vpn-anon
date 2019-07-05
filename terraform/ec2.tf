resource "aws_spot_instance_request" "this" {
  depends_on                  = ["null_resource.spot-ec2"] 
  ami                         = "${data.aws_ami.this.id}"
  instance_type               = "${var.type_sec[var.type]}"
  subnet_id                   = "${var.subnet}"
  vpc_security_group_ids      = ["${aws_security_group.this.id}"]
  associate_public_ip_address = true
  spot_price                  = "${data.local_file.spot-ec2.content}"
  wait_for_fulfillment        = true
  lifecycle {
    ignore_changes = ["ebs_block_device"]
  }

  provisioner "local-exec" {
    command = "aws ec2 create-tags --resources ${aws_spot_instance_request.this.spot_instance_id} --tags Key=Name,Value=${var.owner}-${var.project}"
  }
}