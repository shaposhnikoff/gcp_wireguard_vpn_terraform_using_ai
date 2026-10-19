# Security

## Administrative access

- SSH is allowed only from `ssh_allowed_cidrs`; `0.0.0.0/0` and `::/0` are
  rejected by Terraform variable validation.
- OS Login is enabled. Access follows Google Cloud IAM, not shared SSH keys.
- `block-project-ssh-keys=TRUE` prevents project-wide keys from reaching the VM.
- The serial console is disabled.
- The SSH firewall rule logs connections for audit.

Administrators need `roles/compute.osLogin` or `roles/compute.osAdminLogin`
when `sudo` is required.

## Network

| Rule | Source | Ports | Logging |
|---|---|---|---|
| `allow-ssh` | `ssh_allowed_cidrs` | TCP/22 | full metadata |
| `allow-icmp` | `ssh_allowed_cidrs` | ICMP | no metadata |
| `allow-wireguard` | `vpn_allowed_cidrs` | UDP/51820 | no metadata |
| `deny-all-ingress` | `0.0.0.0/0` | all | no metadata |

The explicit deny at priority 65534 makes blocked traffic visible instead of
relying only on the implicit deny. Because WireGuard clients may roam,
`vpn_allowed_cidrs` defaults to the whole internet; narrow it when client
addresses are stable.

## Identity and permissions

The VM runs as a dedicated service account with no project-level permissions
except:

- `roles/logging.logWriter`
- `roles/monitoring.metricWriter`

The only secret-level grant is `roles/secretmanager.secretVersionAdder` on the
client configuration secret. The VM cannot read the secret back, only add a new
version.

## Secrets and keys

- WireGuard server and client private keys are generated on the VM.
- Terraform never handles private keys and they are not written to state.
- Client configs are stored in Secret Manager as one JSON object.
- Access to the secret is controlled by IAM; read it with
  `gcloud secrets versions access latest`.

## Compute hardening

- Shielded VM with Secure Boot, vTPM and integrity monitoring.
- Debian 12 image family, pinned through `image_project` and `image_family`.
- `deletion_protection = true` by default to prevent accidental loss.
- Boot disk uses Google-managed encryption at rest.

## Checkov exceptions

The scan is blocking. Two checks are skipped in `.checkov.yaml`:

| Check | Reason |
|---|---|
| `CKV_GCP_40` | A public IP is the WireGuard endpoint and the only SSH entry point. It is protected by firewall rules and OS Login. |
| `CKV_GCP_38` | CSEK is deprecated by Google Cloud; disks use Google-managed encryption. |

Any new exception needs a written reason in `.checkov.yaml` and in the pull
request. Fix the configuration when the finding is real.

## Out of scope

- Host-based intrusion detection and file integrity monitoring beyond Shielded VM.
- Automatic WireGuard key rotation.
- Centralized log export and retention beyond the project defaults.
- High availability across zones.
