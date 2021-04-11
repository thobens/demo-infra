#cloud-config
users:
  - name: rancher
    ssh-authorized-keys: ${userdata_ssh_keys}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: /bin/bash
packages:
  - docker.io
runcmd:
  - bash /opt/run.sh  
write_files:
  - path: /opt/run.sh
    encoding: b64
    owner: root:root
    permissions: '0750'
    content: |
      ${userdata_runcmd}