plugin "google" {
  enabled = true
  version = "0.40.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

config {
  call_module_type    = "all"
  force               = false
  disabled_by_default = false
}
