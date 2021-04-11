variable "api_token" {
  description = "API Token for cloud resource provisioning"
  type = string
  sensitive = true
}

variable "ssh_keys" {
  description = "SSH authorized public keys on compute instances"
  type = string
}
