# Troubleshooting

## SSH times out or is refused

1. Confirm the source address is inside `ssh_allowed_cidrs`. The rule allows
   only those ranges; there is no IAP fallback.
2. Check that your Google identity has `roles/compute.osLogin` or
   `roles/compute.osAdminLogin`.
3. Confirm the VM has the `vpn-gateway` network tag.
4. Review the `allow-ssh` firewall logs in Cloud Logging.

## The startup script failed

The bootstrap writes to `/var/log/wireguard-bootstrap.log`. If SSH works:

```bash
sudo tail -n 100 /var/log/wireguard-bootstrap.log
sudo systemctl status wg-quick@wg0
```

A common cause is IAM propagation: the VM may start before
`secretmanager.secretVersionAdder` is effective. The script retries the upload
five times with a ten-second delay. Check that the secret exists and that the
service account has the binding.

The marker file `/var/lib/wireguard-bootstrap.done` prevents a second run.
Remove it only when you intentionally want to regenerate keys and configs.

## WireGuard has no handshake

- Verify the client `Endpoint` matches `terraform output vpn_endpoint`.
- Verify UDP `vpn_port` is open from the client address in
  `vpn_allowed_cidrs`.
- Run `sudo wg show` on the server: the peer public key must match the client
  config.
- Check that the client clock is correct; WireGuard is sensitive to time skew.
- Remember that ICMP being allowed does not imply UDP is allowed.

## Cannot read client configurations

```bash
gcloud secrets versions access latest \
  --secret=wireguard-client-config \
  --project "$PROJECT_ID"
```

`Permission denied` means the caller lacks `roles/secretmanager.secretAccessor`
on the secret. `NOT_FOUND` usually means the VM has not successfully uploaded a
version yet; check the bootstrap log.

## `terraform destroy` fails

The VM has `deletion_protection = true`. Add `deletion_protection = false` to
the environment tfvars, run `make plan` and `make apply`, then `make destroy`.

## `make apply` refuses to run

`make apply` requires a saved `tfplan`. Run `make plan` first, review the diff,
and only then apply. This is intentional.

## CI version check fails

`Version and changelog` requires exactly one patch above `main` and a matching
`## [x.y.z]` section in `CHANGELOG.md`. Run `make version-bump`, add the
English entry, and push. Do not bump by more than one patch unless the workflow
is changed deliberately.

## Checkov fails

The scan is blocking. Read the rule ID in the job log. Fix the configuration
when the finding is real. If it is a deliberate exception, add it to
`.checkov.yaml` with a written reason and mention it in the pull request.
Existing exceptions are `CKV_GCP_40` and `CKV_GCP_38`.

## Plan diff says `no comparison plan`

- On the first run of a pull request the base artifact may not exist yet.
- Artifacts are kept for five days; an old base run may have expired.
- On `main`, the previous successful run must have uploaded `terraform-plan`.

The plan itself is still valid; only the comparison is missing.

## Plan diff does not show the startup script

`metadata_startup_script` contains the static IP, which is unknown until apply
on the first plan. Terraform therefore marks the whole field as known after
apply and the text does not appear in diffs. This is expected.

## `terraform init` cannot find the backend

`backend.tf` is environment specific and ignored by Git. Copy
`backend.tf.example`, set the bucket, and ensure the account has object
permissions on it. For local checks use `terraform init -backend=false`.
