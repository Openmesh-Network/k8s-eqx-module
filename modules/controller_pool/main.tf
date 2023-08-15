data "template_file" "controller-primary" {
  template = file("${path.module}/controller-primary.tpl")

  vars = {
    shortlived_kube_token    = var.shortlived_kube_token
    kube_token               = var.kube_token
    metal_network_cidr       = var.kubernetes_lb_block
    metal_auth_token         = var.auth_token
    equinix_metal_project_id = var.project_id
    kube_version             = var.kubernetes_version
    secrets_encryption       = var.secrets_encryption ? "yes" : "no"
    configure_ingress        = var.configure_ingress ? "yes" : "no"
    count                    = var.count_x86
    count_gpu                = var.count_gpu
    storage                  = var.storage
    skip_workloads           = var.skip_workloads ? "yes" : "no"
    control_plane_node_count = var.control_plane_node_count
    equinix_api_key          = var.auth_token
    equinix_project_id       = var.project_id
    loadbalancer             = local.loadbalancer_config
    loadbalancer_type        = var.loadbalancer_type
    ccm_version              = var.ccm_version
    ccm_enabled              = var.ccm_enabled
    metallb_namespace        = var.metallb_namespace
    metallb_configmap        = var.metallb_configmap
    equinix_metro            = var.metro
  }
}

resource "equinix_metal_device" "k8s_primary" {
  hostname         = "${var.cluster_name}-controller-primary"
  operating_system = "ubuntu_18_04"
  plan             = var.plan_primary
  metro            = var.metro != "" ? var.metro : null
  user_data        = data.template_file.controller-primary.rendered
  tags             = [
    jsonencode({ role : "controller",
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

data "template_file" "controller-standby" {
  template = file("${path.module}/controller-standby.tpl")

  vars = {
    kube_token      = var.kube_token
    primary_node_ip = equinix_metal_device.k8s_primary.network.0.address
    kube_version    = var.kubernetes_version
    storage         = var.storage
  }
}

resource "equinix_metal_device" "k8s_controller_standby" {
  count      = var.control_plane_node_count
  depends_on = [equinix_metal_device.k8s_primary]

  hostname         = format("${var.cluster_name}-controller-standby-%02d", count.index)
  operating_system = "ubuntu_18_04"
  plan             = var.plan_primary
  metro            = var.metro != "" ? var.metro : null
  user_data        = data.template_file.controller-standby.rendered
  tags             = ["kubernetes", "controller-${var.cluster_name}"]
  billing_cycle    = "hourly"
  project_id       = var.project_id
  lifecycle {
    ignore_changes = [user_data]
  }
}

resource "null_resource" "sos_user" {
  connection {
    host        = equinix_metal_device.k8s_primary.network.0.address
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
      host                 = equinix_metal_device.k8s_primary.network.0.address
      ssh_private_key_path = var.ssh_private_key_path
      local_path           = path.root
    }
    command = "sh ${path.module}/../assets/download_sos_password.sh"
  }
}

data "local_file" "sos_user" {
  filename = abspath("${path.root}/${var.cluster_name}-controller-primary_secret.asc")

  depends_on = [
    null_resource.sos_user
  ]
}

resource "null_resource" "kubeconfig" {
  provisioner "local-exec" {
    environment = {
      controller           = equinix_metal_device.k8s_primary.network.0.address
      kube_token           = var.kube_token
      local_path           = path.root
      ssh_private_key_path = var.ssh_private_key_path
    }

    command = "sh ${path.module}/../assets/kubeconfig_copy.sh"
  }

  depends_on = [
    null_resource.key_wait_transfer
  ]
}

data "local_file" "kubeconfig" {
  filename = abspath("${path.root}/kubeconfig")

  depends_on = [
    null_resource.kubeconfig
  ]
}

resource "null_resource" "key_wait_transfer" {
  count = var.control_plane_node_count

  connection {
    type        = "ssh"
    user        = "root"
    host        = equinix_metal_device.k8s_controller_standby[count.index].access_public_ipv4
    private_key = file(var.ssh_private_key_path)
    password    = equinix_metal_device.k8s_controller_standby[count.index].root_password
  }

  provisioner "remote-exec" {
    inline = ["cloud-init status --wait"]
  }

  provisioner "local-exec" {
    environment = {
      controller           = equinix_metal_device.k8s_primary.network.0.address
      node_addr            = equinix_metal_device.k8s_controller_standby[count.index].access_public_ipv4
      kube_token           = var.kube_token
      ssh_private_key_path = var.ssh_private_key_path
    }

    command = "sh ${path.module}/assets/key_wait_transfer.sh"
  }
}

resource "null_resource" "infra_config" {
  connection {
    type        = "ssh"
    user        = "root"
    host        = equinix_metal_device.k8s_primary.network.0.address
    private_key = file(var.ssh_private_key_path)
    password    = equinix_metal_device.k8s_primary.root_password
  }

  provisioner "file" {
    content = templatefile("${path.module}/blank.tpl.json", {content = jsonencode({"kube_token"="${var.kube_token}",
                                                                                   "metal_network_cidr"="${var.kubernetes_lb_block}"
                                                                                   "metal_auth_token"="${var.auth_token}"
                                                                                   "equinix_metal_project_id"="${var.project_id}"
                                                                                   "kube_version"="${var.kubernetes_version}"
                                                                                   "secrets_encryption"="${var.secrets_encryption}"
                                                                                   "configure_ingress"=var.configure_ingress ? "yes" : "no"
                                                                                   "secrets_encryption"=var.secrets_encryption ? "yes" : "no"
                                                                                   "count"=var.count_x86
                                                                                   "count_gpu"=var.count_gpu
                                                                                   "storage"=var.storage
                                                                                   "skip_workloads"=var.skip_workloads ? "yes" : "no"
                                                                                   "control_plane_node_count"=var.control_plane_node_count
                                                                                   "equinix_api_key"=var.auth_token
                                                                                   "equinix_project_id"=var.project_id
                                                                                   "loadbalancer"=local.loadbalancer_config
                                                                                   "loadbalancer_type"=var.loadbalancer_type
                                                                                   "ccm_version"=var.ccm_version
                                                                                   "ccm_enabled"=var.ccm_enabled
                                                                                   "metal_namespace"=var.metallb_namespace
                                                                                   "metal_configmap"=var.metallb_configmap
                                                                                   "equinix_metro"=var.metro
                                                                                   "shortlived_kube_token"=var.shortlived_kube_token
                                                                                  })
                          })
    destination = "/root/infra_config.json"
  }

  depends_on = [
    null_resource.key_wait_transfer
  ]
}

resource "null_resource" "secrets" {
  connection {
    type        = "ssh"
    user        = "root"
    host        = equinix_metal_device.k8s_primary.network.0.address
    private_key = file(var.ssh_private_key_path)
    password    = equinix_metal_device.k8s_primary.root_password
  }

  provisioner "file" {
    content = templatefile("${path.module}/blank.tpl.json", {content = jsonencode(var.gh_secrets)})
    destination = "/root/secrets.json"
  }

  depends_on = [
    null_resource.key_wait_transfer
  ]
}

resource "null_resource" "workloads" {
  connection {
    type        = "ssh"
    user        = "root"
    host        = equinix_metal_device.k8s_primary.network.0.address
    private_key = file(var.ssh_private_key_path)
    password    = equinix_metal_device.k8s_primary.root_password
  }

  provisioner "file" {
    content = templatefile("${path.module}/blank.tpl.json", {content = jsonencode(var.workloads)})
    destination = "/root/workloads.json"
  }

  depends_on = [
    null_resource.key_wait_transfer
  ]
}

resource "equinix_metal_ip_attachment" "kubernetes_lb_block" {
  device_id     = equinix_metal_device.k8s_primary.id
  cidr_notation = var.kubernetes_lb_block
}
