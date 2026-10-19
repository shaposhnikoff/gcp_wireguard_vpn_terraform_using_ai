# WireGuard VPN gateway on Google Cloud

Terraform configuration that provisions a WireGuard VPN gateway in Google
Cloud. The gateway runs on a Shielded Debian VM, exposes only the ports it
needs, and keeps SSH behind an explicit CIDR allowlist.

The project doubles as an example of agentic infrastructure development:
every change goes through a pull request, a mocked Terraform test suite, a
security scan and an offline plan review.

## Pages

- [Architecture](architecture.md) — resources, network flow and boot sequence.
- [Deployment](deployment.md) — prerequisites, state, variables and commands.
- [Security](security.md) — SSH, IAM, secrets, firewall and scan exceptions.
- [CI and verification](ci-and-verification.md) — workflow jobs, plan diffs and reports.
- [Versioning and releases](versioning-and-releases.md) — `VERSION`, changelog, tags and releases.
- [Troubleshooting](troubleshooting.md) — common failures and how to diagnose them.

## What it creates

| Resource | Purpose |
|---|---|
| VPC and subnet | Dedicated network, flow logs enabled |
| Static external IP | Stable WireGuard endpoint and SSH target |
| Firewall rules | SSH and ICMP from admin CIDRs, WireGuard UDP, explicit deny |
| Compute instance | Debian 12, e2-micro, Shielded VM, OS Login only |
| Service account | Runtime identity with minimal permissions |
| Secret Manager secret | Generated WireGuard client configurations |

## Quick start

```bash
cp envs/prod/terraform.tfvars.example envs/prod/terraform.tfvars
# set project_id and ssh_allowed_cidrs
make verify
make plan
make apply
```

Client configurations are generated on first boot and stored in Secret
Manager. See [Deployment](deployment.md) for the full flow.

## Repository

Source code, issues and releases live in
[shaposhnikoff/gcp_wireguard_vpn_terraform_using_ai](https://github.com/shaposhnikoff/gcp_wireguard_vpn_terraform_using_ai).
