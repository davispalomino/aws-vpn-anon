resource "aws_security_group" "this" {
  name        = "sg-${lower(var.owner)}-${lower(var.project)}"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${data.aws_subnet.this.vpc_id}"
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}
resource "aws_security_group_rule" "rule_tcp" {
  count                    = "${length(var.port_tcp)}"
  type                     = "ingress"
  from_port                = "${element(var.port_tcp, count.index)}"
  to_port                  = "${element(var.port_tcp, count.index)}"
  protocol                 = "TCP"
  cidr_blocks              = ["0.0.0.0/0"]
  security_group_id        = "${aws_security_group.this.id}"
}

resource "aws_security_group_rule" "rule_udp" {
  count                    = "${length(var.port_udp)}"
  type                     = "ingress"
  from_port                = "${element(var.port_udp, count.index)}"
  to_port                  = "${element(var.port_udp, count.index)}"
  protocol                 = "UDP"
  cidr_blocks              = ["0.0.0.0/0"]
  security_group_id        = "${aws_security_group.this.id}"
}

resource "aws_security_group_rule" "ping" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "icmp"
  cidr_blocks              = ["0.0.0.0/0"]
  security_group_id        = "${aws_security_group.this.id}"
}