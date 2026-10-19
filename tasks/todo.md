# TODO: WireGuard VPN gateway in GCP

## План

- [x] Уточнить параметры: WireGuard, публичный IP + CIDR allowlist, VPC + VM, GCS state
- [x] Каркас: versions, variables, network, firewall, IAM, compute, outputs
- [x] Startup-шаблон WireGuard с генерацией клиентов и загрузкой в Secret Manager
- [x] Native Terraform tests с mock_provider
- [x] Makefile, verify/security скрипты, Cloud Build, README
- [x] GitHub Actions: fmt, validate, terraform test matrix, tflint, Checkov
- [x] Диаграмма потоков
- [x] Прогнать `terraform fmt -check`, `init -backend=false`, `validate`, `test`
- [x] Проверить шаблон через `bash -n` после рендера
- [ ] Прогнать `tflint` и `checkov`, если установлены (локально не установлены)
- [ ] Ревью плана: отсутствие destroy/replace, корректные CIDR

## Решения

- WireGuard вместо OpenVPN: минимум зависимостей, ключи генерируются на VM.
- Публичный IP + firewall allowlist: соответствует требованию SSH из диапазона.
- State в GCS: командная работа и воспроизводимость.
- Секреты только в Secret Manager: приватные ключи не попадают в state.
- Одна VM: достаточный минимум для первой итерации, HA — следующий шаг.

## Риски

- Потеря зоны = потеря VPN. Нет managed instance group и health check.
- OS Login требует IAM-настройки до первого SSH.
- Startup script зависит от доступности metadata server и Secret Manager API.
- `deletion_protection` требует отдельного шага перед destroy.

## Review

- `terraform fmt -check -recursive` — pass.
- `terraform validate` — pass.
- `terraform test` — 4 passed, 0 failed.
- Rendered startup script — `bash -n` pass.
- `tflint` 0.55.0 + ruleset google 0.40.0 — 0 issues.
- `checkov`, `trivy`, `gitleaks` — не установлены локально, шаги
  добавлены в `scripts/verify.sh`, `scripts/security.sh` и CI.
- `terraform plan` — не запускался: нет `terraform.tfvars` и доступа к проекту.
