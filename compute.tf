resource "google_compute_instance" "vpn" {
  name                      = "${var.name_prefix}-vm"
  machine_type              = var.machine_type
  zone                      = var.zone
  tags                      = [var.instance_tag]
  labels                    = local.common_labels
  deletion_protection       = var.deletion_protection
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image  = "projects/${var.image_project}/global/images/family/${var.image_family}"
      size   = var.boot_disk_size_gb
      type   = var.boot_disk_type
      labels = local.common_labels
    }
  }

  network_interface {
    network    = google_compute_network.vpn.id
    subnetwork = google_compute_subnetwork.vpn.id

    access_config {
      nat_ip = google_compute_address.vpn.address
    }
  }

  service_account {
    email = google_service_account.vpn.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
    serial-port-enable     = "FALSE"
  }

  metadata_startup_script = templatefile("${path.module}/templates/wireguard-bootstrap.sh.tftpl", {
    project_id         = var.project_id
    secret_name        = var.secret_name
    vpn_port           = var.vpn_port
    vpn_server_address = local.vpn_server_address
    vpn_prefix_length  = local.vpn_prefix_length
    vpn_subnet_cidr    = var.vpn_subnet_cidr
    client_names       = local.client_names
    public_ip          = google_compute_address.vpn.address
  })

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
  }

  depends_on = [
    google_secret_manager_secret_iam_member.vpn_version_adder,
    google_compute_firewall.ssh,
    google_compute_firewall.wireguard,
  ]
}
