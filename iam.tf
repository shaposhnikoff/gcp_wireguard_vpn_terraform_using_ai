resource "google_service_account" "vpn" {
  account_id   = "${var.name_prefix}-vm"
  display_name = "WireGuard VPN gateway"
  description  = "Runtime identity for the WireGuard gateway. No project-level permissions."
}

resource "google_project_iam_member" "vpn_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vpn.email}"
}

resource "google_project_iam_member" "vpn_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vpn.email}"
}

resource "google_secret_manager_secret" "client_config" {
  secret_id = var.secret_name
  labels    = local.common_labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "vpn_version_adder" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.client_config.secret_id
  role      = "roles/secretmanager.secretVersionAdder"
  member    = "serviceAccount:${google_service_account.vpn.email}"
}
