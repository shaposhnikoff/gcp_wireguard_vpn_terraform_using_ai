resource "google_compute_firewall" "ssh" {
  name        = "${var.name_prefix}-allow-ssh"
  network     = google_compute_network.vpn.name
  direction   = "INGRESS"
  priority    = 1000
  description = "SSH access from the approved administrative ranges only."

  source_ranges = var.ssh_allowed_cidrs
  target_tags   = [var.instance_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "icmp_diagnostics" {
  name        = "${var.name_prefix}-allow-icmp"
  network     = google_compute_network.vpn.name
  direction   = "INGRESS"
  priority    = 1000
  description = "ICMP diagnostics from the approved administrative ranges only."

  source_ranges = var.ssh_allowed_cidrs
  target_tags   = [var.instance_tag]

  allow {
    protocol = "icmp"
  }

  log_config {
    metadata = "EXCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "wireguard" {
  name        = "${var.name_prefix}-allow-wireguard"
  network     = google_compute_network.vpn.name
  direction   = "INGRESS"
  priority    = 1000
  description = "WireGuard UDP listener."

  source_ranges = var.vpn_allowed_cidrs
  target_tags   = [var.instance_tag]

  allow {
    protocol = "udp"
    ports    = [tostring(var.vpn_port)]
  }

  log_config {
    metadata = "EXCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "deny_all_ingress" {
  name        = "${var.name_prefix}-deny-all-ingress"
  network     = google_compute_network.vpn.name
  direction   = "INGRESS"
  priority    = 65534
  description = "Explicit lowest-priority deny for audit visibility. GCP also has an implicit deny."

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.instance_tag]

  deny {
    protocol = "all"
  }

  log_config {
    metadata = "EXCLUDE_ALL_METADATA"
  }
}
