provider "hcloud" {
  token = var.api_token
}

resource "hcloud_server" "server" {
  name        = "rancher"
  server_type = "cx11"
  image       = "ubuntu-20.04"
  location    = "nbg1"
  user_data   = template_file.user_data_file.rendered

  network {
      network_id = hcloud_network.network.id
      ip         = "10.0.1.5"
      alias_ips  = [
        "10.0.1.6",
        "10.0.1.7"
      ]
  }

  # **Note**: the depends_on is important when directly attaching the
  # server to a network. Otherwise Terraform will attempt to create
  # server and sub-network in parallel. This may result in the server
  # creation failing randomly.
  depends_on = [
    hcloud_network_subnet.network-subnet
  ]
}