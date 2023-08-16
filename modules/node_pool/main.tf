data "template_file" "node" {
  template = file("${path.module}/node.tpl")

  vars = {
    kube_token      = var.kube_token
    primary_node_ip = var.controller_address
    kube_version    = var.kubernetes_version
    ccm_enabled     = var.ccm_enabled
    storage         = var.storage
  }
}

resource "equinix_metal_device" "x86_node" {
  hostname         = format("${var.cluster_name}-x86-${var.pool_label}-%02d", count.index)
  operating_system = "ubuntu_18_04"
  count            = var.count_x86
  plan             = var.plan_x86
  metro            = var.metro != "" ? var.metro : null
  user_data        = data.template_file.node.rendered
  tags             = [
    jsonencode({ role : "node",
                 cluster_name: var.cluster_name,
                 infra_version: "v3"
              })
  ]

  billing_cycle = "hourly"
  project_id    = var.project_id
  lifecycle {
    ignore_changes = [user_data]
  }
}

resource "equinix_metal_device" "arm_node" {
  hostname         = format("${var.cluster_name}-arm-${var.pool_label}-%02d", count.index)
  operating_system = "ubuntu_18_04"
  count            = var.count_arm
  plan             = var.plan_arm
  metro            = var.metro
  user_data        = data.template_file.node.rendered
  tags             = ["kubernetes", "pool-${var.cluster_name}-${var.pool_label}-arm"]

  billing_cycle = "hourly"
  project_id    = var.project_id
  lifecycle {
    ignore_changes = [user_data]
  }
}

resource "null_resource" "infra_config" {
  count = var.count_x86

  connection {
    type        = "ssh"
    user        = "root"
    host        = element(equinix_metal_device.x86_node.*.network.0.address, count.index)
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content = templatefile("${path.module}/blank.tpl.json", {content = jsonencode({"kube_token"="${var.kube_token}"
                                                                                   "primary_node_ip"="${var.controller_address}"
                                                                                   "kube_version"="${var.kubernetes_version}"
                                                                                   "ccm_enabled"="${var.ccm_enabled}"
                                                                                   "storage"="${var.storage}"
                                                                                  })
                          })
    destination = "/root/infra_config.json"
  }
}

resource "null_resource" "secrets" {
  count = var.count_x86

  connection {
    type        = "ssh"
    user        = "root"
    host        = element(equinix_metal_device.x86_node.*.network.0.address, count.index)
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content = templatefile("${path.module}/blank.tpl.json", {content = jsonencode(var.gh_secrets)})
    destination = "/root/secrets.json"
  }
}

resource "null_resource" "sos_user" {
  count = var.count_x86

  connection {
    host        = element(equinix_metal_device.x86_node.*.network.0.address, count.index)
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    source      = "${path.module}/../assets/create_sos_user.sh"
    destination = "/tmp/create_sos_user.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/create_sos_user.sh",
      "/tmp/create_sos_user.sh"
    ]
  }

  provisioner "local-exec" {
    environment = {
      host                  = element(equinix_metal_device.x86_node.*.network.0.address, count.index)
      ssh_private_key_path = var.ssh_private_key_path
      local_path           = path.root
    }
    command = "sh ${path.module}/../assets/download_sos_password.sh"
  }
}
