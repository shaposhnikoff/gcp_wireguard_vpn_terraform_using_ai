plugin "google" {
  enabled = true
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

config {
  module              = true
  force               = false
  disabled_by_default = false
}
