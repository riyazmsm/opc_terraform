variable user {default = ""}
variable password { default = ""}
variable domain { default = ""}
variable endpoint { default = "https://compute.aucom-east-1.oraclecloud.com/"}

variable "public_ssh_key" {
  default = "./keys/id_rsa.pub"
}
variable "private_ssh_key" {
  default = "./keys/id_rsa"
}
