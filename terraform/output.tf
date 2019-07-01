output "ami" {
  value = "${data.aws_ami.this.id}"
}
output "type" {
  value = "${var.type_sec[var.type]}"
}

output "az" {
  value = "${data.aws_subnet.this.availability_zone}"
}

output "price" {
  value = "${data.local_file.spot-ec2.content}"
}
output "ipPublic" {
  value = "${aws_instance.this.public_ip}"
}