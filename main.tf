resource "equinix_metal_project" "new_project" {
  count = var.metal_create_project ? 1 : 0

  name            = var.equinix_metal_project_name
  organization_id = var.organization_id != "" ? var.organization_id : null

  # Kube-vip will enable BGP if not enabled, Terraform must match the settings
  bgp_config {
    deployment_type = "local"
    md5             = ""
    asn             = 65000
  }
}

locals {
  ssh_key_name = "metal_key"
}

resource "random_id" "cloud" {
  byte_length = 8
}

resource "tls_private_key" "ssh_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "cluster_private_key_pem" {
  content         = chomp(tls_private_key.ssh_key_pair.private_key_pem)
  filename        = pathexpand(format("%s", local.ssh_key_name))
  file_permission = "0600"
}

resource "local_file" "cluster_public_key" {
  content         = chomp(tls_private_key.ssh_key_pair.public_key_openssh)
  filename        = pathexpand(format("%s.pub", local.ssh_key_name))
  file_permission = "0600"
}

resource "equinix_metal_project_ssh_key" "kubernetes_on_metal" {
  name       = format("master-key-%s", var.cluster_name)
  public_key = chomp(tls_private_key.ssh_key_pair.public_key_openssh)
  project_id = var.metal_create_project ? equinix_metal_project.new_project[0].id : var.project_id
}

resource "equinix_metal_reserved_ip_block" "kubernetes" {
  count      = var.metal_create_project ? 1 : 0

  project_id = var.metal_create_project ? equinix_metal_project.new_project[0].id : var.project_id
  metro      = var.metro != "" ? var.metro : null
  quantity   = 4
}
