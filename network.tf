resource "google_compute_network" "vpn" {
  name                    = "${var.name_prefix}-net"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  description             = "Dedicated VPC for the WireGuard VPN gateway."
}

resource "google_compute_subnetwork" "vpn" {
  name                     = "${var.name_prefix}-subnet"
  ip_cidr_range            = var.network_cidr
  region                   = var.region
  network                  = google_compute_network.vpn.id
  private_ip_google_access = true
  description              = "Gateway subnet. No other workloads are placed here."

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_address" "vpn" {
  name         = "${var.name_prefix}-ip"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
  description  = "Stable public endpoint for the WireGuard VPN gateway."
}
