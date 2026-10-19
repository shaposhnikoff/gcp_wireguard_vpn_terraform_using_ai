locals {
  vpn_server_address = cidrhost(var.vpn_subnet_cidr, 1)
  vpn_prefix_length  = tonumber(split("/", var.vpn_subnet_cidr)[1])
  client_names       = join(",", var.vpn_client_names)

  common_labels = merge(
    {
      managed-by  = "terraform"
      component   = "wireguard-gateway"
      environment = "prod"
    },
    var.labels,
  )
}
