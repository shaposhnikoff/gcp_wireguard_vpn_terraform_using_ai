mock_provider "google" {}

run "plan_defaults" {
  command = plan

  variables {
    project_id        = "test-project"
    ssh_allowed_cidrs = ["203.0.113.0/24"]
  }

  assert {
    condition     = google_compute_firewall.ssh.source_ranges == toset(["203.0.113.0/24"])
    error_message = "SSH firewall must only allow the configured source ranges."
  }

  assert {
    condition     = google_compute_firewall.deny_all_ingress.priority == 65534
    error_message = "An explicit lowest-priority deny rule must exist for audit visibility."
  }

  assert {
    condition     = google_compute_firewall.icmp_diagnostics.source_ranges == toset(["203.0.113.0/24"])
    error_message = "ICMP diagnostics must only be allowed from the administrative ranges."
  }

  assert {
    condition     = length([for rule in google_compute_firewall.icmp_diagnostics.allow : rule if rule.protocol == "icmp"]) == 1
    error_message = "The diagnostics rule must allow ICMP."
  }

  assert {
    condition     = length([for rule in google_compute_firewall.deny_all_ingress.deny : rule if rule.protocol == "all"]) == 1
    error_message = "The fallback rule must deny all remaining ingress traffic."
  }

  assert {
    condition     = google_compute_instance.vpn.metadata["enable-oslogin"] == "TRUE"
    error_message = "OS Login must be enabled on the gateway VM."
  }

  assert {
    condition     = google_compute_instance.vpn.metadata["block-project-ssh-keys"] == "TRUE"
    error_message = "Project-wide SSH keys must be blocked on the gateway VM."
  }

  assert {
    condition     = google_compute_instance.vpn.deletion_protection == true
    error_message = "Deletion protection must be enabled by default."
  }

  assert {
    condition     = google_secret_manager_secret.client_config.secret_id == "wireguard-client-config"
    error_message = "Client configuration must be stored in the expected Secret Manager secret."
  }

  assert {
    condition     = length([for rule in google_compute_firewall.wireguard.allow : rule if rule.protocol == "udp" && contains(rule.ports, "51820")]) == 1
    error_message = "WireGuard UDP 51820 must be open to the configured VPN source ranges."
  }
}

run "custom_port_and_clients" {
  command = plan

  variables {
    project_id        = "test-project"
    ssh_allowed_cidrs = ["198.51.100.7/32"]
    vpn_port          = 4443
    vpn_client_names  = ["laptop", "phone"]
    name_prefix       = "vpn-test"
  }

  assert {
    condition     = length([for rule in google_compute_firewall.wireguard.allow : rule if contains(rule.ports, "4443")]) == 1
    error_message = "Custom VPN port must be reflected in the firewall rule."
  }

  assert {
    condition     = google_compute_firewall.ssh.name == "vpn-test-allow-ssh"
    error_message = "Resource names must follow the configured prefix."
  }

  assert {
    condition     = google_compute_instance.vpn.name == "vpn-test-vm"
    error_message = "Instance name must follow the configured prefix."
  }
}

run "rejects_world_open_ssh" {
  command = plan

  variables {
    project_id        = "test-project"
    ssh_allowed_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.ssh_allowed_cidrs]
}

run "rejects_empty_client_list" {
  command = plan

  variables {
    project_id        = "test-project"
    ssh_allowed_cidrs = ["203.0.113.0/24"]
    vpn_client_names  = []
  }

  expect_failures = [var.vpn_client_names]
}
