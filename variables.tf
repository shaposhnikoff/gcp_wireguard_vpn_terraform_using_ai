variable "project_id" {
  description = "GCP project ID where the WireGuard gateway is deployed."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID."
  }
}

variable "region" {
  description = "Region for the VPC, subnet, static IP and instance."
  type        = string
  default     = "europe-central2"
}

variable "zone" {
  description = "Zone for the gateway VM."
  type        = string
  default     = "europe-central2-a"
}

variable "name_prefix" {
  description = "Prefix used for all resource names."
  type        = string
  default     = "vpn-gw"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.name_prefix))
    error_message = "name_prefix must be 2-21 lowercase alphanumeric or hyphen characters."
  }
}

variable "network_cidr" {
  description = "CIDR range of the gateway subnet."
  type        = string
  default     = "10.10.0.0/24"

  validation {
    condition     = can(cidrhost(var.network_cidr, 0))
    error_message = "network_cidr must be a valid CIDR range."
  }
}

variable "ssh_allowed_cidrs" {
  description = "Source CIDR ranges allowed to reach TCP/22. Must not be world-open."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.ssh_allowed_cidrs) > 0
    error_message = "At least one SSH source range is required."
  }

  validation {
    condition     = alltrue([for cidr in var.ssh_allowed_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Every entry in ssh_allowed_cidrs must be a valid CIDR range."
  }

  validation {
    condition = alltrue([
      for cidr in var.ssh_allowed_cidrs : cidr != "0.0.0.0/0" && cidr != "::/0"
    ])
    error_message = "SSH must not be exposed to the whole internet. Use explicit source ranges."
  }
}

variable "vpn_allowed_cidrs" {
  description = "Source CIDR ranges allowed to reach the WireGuard UDP port."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for cidr in var.vpn_allowed_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Every entry in vpn_allowed_cidrs must be a valid CIDR range."
  }
}

variable "vpn_port" {
  description = "UDP port used by the WireGuard listener."
  type        = number
  default     = 51820

  validation {
    condition     = var.vpn_port >= 1024 && var.vpn_port <= 65535
    error_message = "vpn_port must be between 1024 and 65535."
  }
}

variable "vpn_subnet_cidr" {
  description = "Point-to-point subnet used inside the WireGuard tunnel."
  type        = string
  default     = "10.66.66.0/24"

  validation {
    condition     = can(cidrhost(var.vpn_subnet_cidr, 1))
    error_message = "vpn_subnet_cidr must be a valid CIDR range."
  }
}

variable "vpn_client_names" {
  description = "Client configs to generate on first boot and store in Secret Manager."
  type        = list(string)
  default     = ["client1"]

  validation {
    condition     = length(var.vpn_client_names) > 0 && length(var.vpn_client_names) <= 50
    error_message = "Provide between 1 and 50 client names."
  }

  validation {
    condition = alltrue([
      for name in var.vpn_client_names : can(regex("^[a-z0-9][a-z0-9-]{0,30}$", name))
    ])
    error_message = "Client names must be lowercase alphanumeric or hyphen characters."
  }

  validation {
    condition     = length(distinct(var.vpn_client_names)) == length(var.vpn_client_names)
    error_message = "Client names must be unique."
  }
}

variable "machine_type" {
  description = "Machine type for the gateway VM."
  type        = string
  default     = "e2-micro"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB."
  type        = number
  default     = 20

  validation {
    condition     = var.boot_disk_size_gb >= 10
    error_message = "boot_disk_size_gb must be at least 10 GB."
  }
}

variable "boot_disk_type" {
  description = "Boot disk type."
  type        = string
  default     = "pd-balanced"
}

variable "image_project" {
  description = "Project that hosts the VM image."
  type        = string
  default     = "debian-cloud"
}

variable "image_family" {
  description = "Image family for the gateway VM."
  type        = string
  default     = "debian-12"
}

variable "instance_tag" {
  description = "Network tag used to target firewall rules at the gateway."
  type        = string
  default     = "vpn-gateway"
}

variable "secret_name" {
  description = "Secret Manager secret that stores generated client configs."
  type        = string
  default     = "wireguard-client-config"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,255}$", var.secret_name))
    error_message = "secret_name must be a valid Secret Manager secret ID."
  }
}

variable "deletion_protection" {
  description = "Protect the VM from accidental destruction. Set to false only for teardown."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Additional labels applied to supported resources."
  type        = map(string)
  default     = {}
}
