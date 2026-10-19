# Deployment

## Prerequisites

- Terraform 1.9 or newer.
- A Google Cloud project with billing enabled.
- Rights to create networks, firewall rules, service accounts, secrets and
  Compute instances.
- `gcloud` and `gh` for the convenience commands below.

Enable the required APIs once:

```bash
gcloud services enable \
  compute.googleapis.com \
  secretmanager.googleapis.com \
  iam.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com \
  --project "$PROJECT_ID"
```

For SSH, grant the administrator an OS Login role:

```bash
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "user:you@example.com" \
  --role roles/compute.osLogin
```

## Remote state

Create the state bucket outside Terraform:

```bash
gcloud storage buckets create "gs://${PROJECT_ID}-tfstate" \
  --project "$PROJECT_ID" \
  --location europe-central2 \
  --uniform-bucket-level-access \
  --public-access-prevention

gcloud storage buckets update "gs://${PROJECT_ID}-tfstate" --versioning
```

Then copy the backend template and set the bucket name:

```bash
cp backend.tf.example backend.tf
```

`backend.tf` is ignored by Git because the bucket name is environment specific.

## Variables

```bash
cp envs/prod/terraform.tfvars.example envs/prod/terraform.tfvars
```

Required changes:

| Variable | Meaning |
|---|---|
| `project_id` | Target project |
| `ssh_allowed_cidrs` | Admin networks allowed to reach TCP/22 and ICMP |
| `vpn_client_names` | Clients for which configs are generated |

`ssh_allowed_cidrs` must not contain `0.0.0.0/0`; the variable validation
rejects it. `vpn_allowed_cidrs` defaults to the whole internet because VPN
clients may roam.

## Verify and deploy

```bash
make verify        # fmt, version check, init, validate, tests, optional scanners
make plan          # writes tfplan and prints the diff
make plan-json     # plan.json for policy checks
make apply         # applies exactly the saved tfplan
```

`make apply` refuses to run without `tfplan`. Pull requests run the same checks
plus an offline plan and a Checkov scan; see
[CI and verification](ci-and-verification.md).

## After apply

```bash
terraform output vpn_public_ip
terraform output ssh_command
terraform output client_config_secret
```

Check the VM:

```bash
gcloud compute ssh vpn-gw-vm --zone europe-central2-a --project "$PROJECT_ID"
sudo systemctl status wg-quick@wg0
sudo wg show
sudo tail -n 50 /var/log/wireguard-bootstrap.log
```

Expected: `wg0` is active, the listen port matches `vpn_port`, and each
configured client has a peer.

## Client configuration

The bootstrap stores client configs as a JSON object in Secret Manager:

```bash
gcloud secrets versions access latest \
  --secret=wireguard-client-config \
  --project "$PROJECT_ID" \
  | jq -r '.laptop' > laptop.conf
```

Import the file into the WireGuard client or run `sudo wg-quick up ./laptop.conf`.
Private keys never appear in Terraform state or outputs.

## Teardown

The VM has `deletion_protection = true`. To destroy everything:

```bash
# add to envs/prod/terraform.tfvars:
# deletion_protection = false
make plan
make apply
make destroy
```

The state bucket and old secret versions are removed separately.
