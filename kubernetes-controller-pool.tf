module "controllers" {
  source = "./modules/controller_pool"

  kube_token               = module.kube_token_1.token
  shortlived_kube_token    = var.shortlived_kube_token
  kubernetes_version       = var.kubernetes_version
  count_x86                = var.count_x86
  count_gpu                = var.count_gpu
  plan_primary             = var.plan_primary
  metro                    = var.metro
  cluster_name             = var.cluster_name
  kubernetes_lb_block      = equinix_metal_reserved_ip_block.kubernetes.cidr_notation
  project_id               = var.metal_create_project ? equinix_metal_project.new_project[0].id : var.project_id
  auth_token               = var.auth_token
  secrets_encryption       = var.secrets_encryption
  configure_ingress        = var.configure_ingress
  storage                  = var.storage
  workloads                = var.workloads
  skip_workloads           = var.skip_workloads
  control_plane_node_count = var.control_plane_node_count
  ssh_private_key_path     = abspath(local_file.cluster_private_key_pem.filename)
  ccm_enabled              = var.ccm_enabled
  loadbalancer_type        = var.loadbalancer_type
  gh_secrets               = var.gh_secrets

  depends_on = [
    equinix_metal_project_ssh_key.kubernetes_on_metal # if the primary node is created before the equinix_metal_project_ssh_key, then the primary node won't be accessible
  ]
}
