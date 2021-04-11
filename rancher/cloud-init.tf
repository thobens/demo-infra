resource "template_file" "user_data_file" {
  template = file("./cloud-config.tpl")
  vars = {
    userdata_ssh_keys = "${var.ssh_keys}"
    userdata_runcmd = "${base64encode(file("run.sh"))}"
  }
}