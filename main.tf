provider "opc" {
  user            = "${var.user}"
  password        = "${var.password}"
  identity_domain = "${var.domain}"
  endpoint        = "${var.endpoint}"
}

resource "opc_compute_ssh_key" "streamvm-ssh-key" {
  name    = "streamvm-ssh-key"
  key     = "${file(var.public_ssh_key)}"
  enabled = true
}

resource "opc_compute_ip_address_reservation" "streamvm-ip-address" {
  name            = "streamvm-ip-address"
  ip_address_pool = "public-ippool"
}

resource "opc_compute_ip_network" "streamvm-ip-network" {
  name              = "streamvm-ip-network"
  ip_address_prefix = "192.168.1.0/24"
}

resource "opc_compute_acl" "streamvm-acl" {
  name = "streamvm-acl"
}

resource "opc_compute_security_rule" "ssh" {
  name               = "Allow-ssh-ingress"
  flow_direction     = "ingress"
  acl                = "${opc_compute_acl.streamvm-acl.name}"
  security_protocols = ["${opc_compute_security_protocol.ssh.name}"]
}

resource "opc_compute_security_rule" "kafka" {
  name               = "Allow-kafka-ingress"
  flow_direction     = "ingress"
  acl                = "${opc_compute_acl.streamvm-acl.name}"
  security_protocols = ["${opc_compute_security_protocol.kafka.name}"]
}

resource "opc_compute_security_rule" "egress" {
  name               = "Allow-all-egress"
  flow_direction     = "egress"
  acl                = "${opc_compute_acl.streamvm-acl.name}"
  security_protocols = ["${opc_compute_security_protocol.all.name}"]
}

resource "opc_compute_security_protocol" "all" {
  name        = "all"
  ip_protocol = "all"
}

resource "opc_compute_security_protocol" "ssh" {
  name        = "ssh"
  dst_ports   = ["22"]
  ip_protocol = "tcp"
}
resource "opc_compute_security_protocol" "kafka" {
  name        = "kafka"
  dst_ports   = ["29092"]
  ip_protocol = "tcp"
}

resource "opc_compute_vnic_set" "streamvm-vnic-set" {
  name         = "streamvm-vnic-set"
  applied_acls = ["${opc_compute_acl.streamvm-acl.name}"]
}

resource "opc_compute_storage_volume" "boot-volume" {
  size = "100"
  name = "boot-volume"
  bootable = true
  image_list = "/oracle/public/OL_7.2_UEKR4_x86_64"
  image_list_entry = 1
}
resource "opc_compute_instance" "streamvm-instance" {
  name       = "streamvm"
  hostname   = "streamvm"
  label      = "streamvm"
  shape      = "oc4"

 storage {
    index = 1
    volume = "${opc_compute_storage_volume.boot-volume.name}"
  }
  boot_order = [ 1 ]

  networking_info {
    index              = 0
    ip_network         = "${opc_compute_ip_network.streamvm-ip-network.name}"
    ip_address         = "192.168.1.100"
    is_default_gateway = true
    vnic_sets          = ["${opc_compute_vnic_set.streamvm-vnic-set.name}"]
    nat                = ["${opc_compute_ip_address_reservation.streamvm-ip-address.name}"]
  }

  ssh_keys = ["${opc_compute_ssh_key.streamvm-ssh-key.name}"]
}

output "public_ip_address" {
  value = "${opc_compute_ip_address_reservation.streamvm-ip-address.ip_address}"
}

resource "null_resource" "vm" {
count = 1
connection {
    type        = "ssh"
    host        = "${opc_compute_ip_address_reservation.streamvm-ip-address.ip_address}"
    user        = "opc"
    private_key = "${file(var.private_ssh_key)}"
  }
provisioner "file" {
  source      = "public-yum-ol7.repo"
  destination = "/home/opc/public-yum-ol7.repo"
}  
provisioner "remote-exec" {
    inline = [
      "sudo yum -y install telnet","sudo mv /home/opc/public-yum-ol7.repo /etc/yum.repos.d/","sudo yum -y install docker-engine",
      "sudo yum -y install curl","sudo curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose","sudo chmod +x /usr/local/bin/docker-compose","sudo yum -y install git","sudo systemctl start docker",
    ]
  }
}
