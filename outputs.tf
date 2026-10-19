output "vpn_public_ip" {
  description = "Stable public IP of the WireGuard gateway."
  value       = google_compute_address.vpn.address
}

output "vpn_endpoint" {
  description = "WireGuard endpoint in host:port form."
  value       = "${google_compute_address.vpn.address}:${var.vpn_port}"
}

output "instance_name" {
  description = "Gateway VM name."
  value       = google_compute_instance.vpn.name
}

output "instance_zone" {
  description = "Gateway VM zone."
  value       = google_compute_instance.vpn.zone
}

output "ssh_command" {
  description = "OS Login based SSH command. Requires roles/compute.osLogin and an SSH key registered with OS Login."
  value       = "gcloud compute ssh ${google_compute_instance.vpn.name} --zone=${google_compute_instance.vpn.zone} --project=${var.project_id}"
}

output "client_config_secret" {
  description = "Secret Manager secret holding the generated client configs as JSON."
  value       = google_secret_manager_secret.client_config.secret_id
}

output "client_config_secret_id" {
  description = "Fully qualified Secret Manager secret resource name."
  value       = google_secret_manager_secret.client_config.id
}
