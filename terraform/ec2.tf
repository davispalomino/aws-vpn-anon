resource "aws_instance" "this" {
  depends_on                  = ["null_resource.spot-ec2"] 
  ami                         = "${data.aws_ami.this.id}"
  instance_type               = "${var.type_sec[var.type]}"
  subnet_id                   = "${var.subnet}"
  vpc_security_group_ids      = ["${aws_security_group.this.id}"]
  associate_public_ip_address = true
  tags = {
    Name  = "${var.owner}-${var.project}"
  }
  lifecycle {
    ignore_changes = ["ebs_block_device"]
  }
}