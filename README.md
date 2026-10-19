# WireGuard VPN gateway в Google Cloud

Terraform-модуль, который поднимает в GCP виртуальную машину с WireGuard и
закрывает SSH доступом только с разрешённых CIDR. Проект собран как пример
agentic-разработки: инфраструктура описывается кодом, а каждое изменение
проходит проверяемые gate'ы до `apply`.

## Что создаётся

| Ресурс | Назначение |
|---|---|
| `google_compute_network` | Отдельный VPC без авто-подсетей |
| `google_compute_subnetwork` | Подсеть `10.10.0.0/24`, flow logs включены |
| `google_compute_address` | Статический внешний IP для VPN |
| `google_compute_firewall.ssh` | TCP/22 только с `ssh_allowed_cidrs`, логирование |
| `google_compute_firewall.wireguard` | UDP/51820 для клиентов |
| `google_compute_firewall.deny_all_ingress` | Явный deny на всё остальное, priority 65534 |
| `google_compute_instance` | Debian 12, e2-micro, Shielded VM, OS Login, без project SSH keys |
| `google_service_account` | Отдельный runtime SA без project-level ролей |
| `google_secret_manager_secret` | Клиентские конфиги WireGuard в JSON |

Схема потоков: [docs/diagrams/ssh-vpn-access-flow.md](docs/diagrams/ssh-vpn-access-flow.md).

## Требования

- Terraform >= 1.9
- Включённые API: `compute.googleapis.com`, `secretmanager.googleapis.com`,
  `iam.googleapis.com`, `logging.googleapis.com`, `monitoring.googleapis.com`
- Права на создание сети, VM, SA, firewall и секрета в целевом проекте
- Для SSH: OS Login и `roles/compute.osLogin` у администратора (или
  `roles/compute.osAdminLogin` для sudo)

```bash
gcloud services enable \
  compute.googleapis.com \
  secretmanager.googleapis.com \
  iam.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com \
  --project "$PROJECT_ID"
```

## 1. Bootstrap state bucket

State хранится в GCS. Bucket создаётся один раз, вне Terraform:

```bash
gcloud storage buckets create "gs://${PROJECT_ID}-tfstate" \
  --project "$PROJECT_ID" \
  --location europe-central2 \
  --uniform-bucket-level-access \
  --public-access-prevention

gcloud storage buckets update "gs://${PROJECT_ID}-tfstate" --versioning
```

Затем:

```bash
cp backend.tf.example backend.tf
# отредактируйте bucket в backend.tf
```

`backend.tf` в `.gitignore`: имя bucket зависит от окружения.

## 2. Переменные

```bash
cp envs/prod/terraform.tfvars.example envs/prod/terraform.tfvars
```

Обязательно замените:

- `project_id`
- `ssh_allowed_cidrs` — точные адреса офиса, домашней сети или jump host.
  Значение `0.0.0.0/0` отклоняется validation-правилом.
- `vpn_client_names` — имена клиентов, для которых будут сгенерированы конфиги.

## 3. Проверка и деплой

```bash
make verify        # fmt, init, validate, terraform test + опциональные сканеры
make plan          # сохраняет tfplan, печатает diff
make plan-json     # plan.json для policy-проверок
make apply         # применяет ровно сохранённый tfplan
```

`make plan` использует `-detailed-exitcode`: код 2 означает «есть изменения» и
не считается ошибкой. `make apply` откажется работать без `tfplan` — это
защита от применения незаreview'енного плана.

## 4. Проверка после apply

```bash
terraform output vpn_public_ip
terraform output ssh_command

gcloud compute ssh vpn-gw-vm --zone europe-central2-a --project "$PROJECT_ID"
```

На VM:

```bash
sudo systemctl status wg-quick@wg0
sudo wg show
sudo tail -n 50 /var/log/wireguard-bootstrap.log
```

Ожидаемо: `wg0` в состоянии `active`, у интерфейса есть listen port и peers.

## 5. Клиентские конфиги

При первом boot VM генерирует ключи и складывает конфиги в Secret Manager в
виде JSON `{ "client1": "<wireguard config>" }`:

```bash
gcloud secrets versions access latest \
  --secret=wireguard-client-config \
  --project "$PROJECT_ID" \
  | jq -r '.laptop' > laptop.conf

sudo wg-quick up ./laptop.conf    # или импорт в клиент WireGuard
```

Приватные ключи никогда не попадают в Terraform state и в вывод `terraform
output`.

## Безопасность

- SSH только с явного allowlist; `0.0.0.0/0` запрещён validation.
- ICMP (ping/traceroute) разрешён только с тех же административных диапазонов.
- OS Login, `block-project-ssh-keys=TRUE`, serial console выключена.
- Shielded VM: Secure Boot, vTPM, integrity monitoring.
- VM работает под отдельным SA; project-level роли — только
  `logging.logWriter` и `monitoring.metricWriter`.
- У SA есть только `secretmanager.secretVersionAdder` на один секрет.
- WireGuard-ключи создаются на VM; в Secret Manager уходит только результат.
- `deletion_protection = true` по умолчанию.
- Firewall flow logs и logging правил включены.

## CI в GitHub Actions

`.github/workflows/terraform.yml` запускается на каждый `pull_request`, на
push в `main` и вручную через `workflow_dispatch`:

| Job | Что делает |
|---|---|
| `fmt` | `terraform fmt -check -recursive -diff` |
| `version` | Проверка `VERSION` и записи в `CHANGELOG.md`; на PR — ровно +1 patch к `main` |
| `plan` | Offline `terraform plan` без backend и без GCP-кредов; план публикуется в PR |
| `validate-and-test` | `init -backend=false`, `validate`, `terraform test` на Terraform 1.9.8 и 1.15.6 |
| `tflint` | `tflint --init` + `tflint --recursive` с Google ruleset 0.40.0 |
| `security` | Checkov, **блокирующий**; исключения описаны в `.checkov.yaml` |
| `report` | Финальный Job Summary со статусом всех gate'ов и счётчиками тестов |

GCP-креды и секреты не нужны. Тесты используют `mock_provider`, а offline-план
работает без backend и без реальных credentials: провайдеру передаётся
фиктивный статический токен, refresh отключён. `apply` в CI не выполняется.

### Offline-план в PR

Job `plan` собирает план из пустого локального state:

- `terraform init -backend=false` — без GCS;
- `-refresh=false -lock=false` — без чтения реального state и без API-запросов;
- `envs/ci/terraform.tfvars.json` — фиксированные тестовые значения;
- `GOOGLE_OAUTH_ACCESS_TOKEN=ci-offline-plan-token` — заглушка, чтобы провайдер
  сконфигурировался.

Результат:

- комментарий в PR с планом под `<details>`; при повторном запуске он
  обновляется, а не дублируется;
- секция **Changes since previous plan** с unified diff против плана из
  предыдущего запуска этого же PR;
- артефакты `terraform-plan` (`plan.txt`, `plan.log`, `tfplan`, `plan.diff`,
  `plan-diff-stat.txt`) с retention 5 дней.

Как считается diff: job скачивает artifact `terraform-plan` из последнего
успешного запуска и сравнивает его с текущим планом.

- На `pull_request` сравнение идёт с base branch (`main`) — секция
  **Changes since main** показывает, что приносит PR. Дополнительно план
  сравнивается с предыдущим комментарием этого PR — секция
  **Changes since previous run** показывает инкремент между push'ами.
- На push в `main` сравнение идёт с предыдущим успешным запуском на `main`,
  поэтому в отчёте видно, что изменил merge. Строка про предыдущий push PR
  в этом случае пишет `n/a on main`.

Если сравнение недоступно (первый запуск или истёк artifact), секция пишет
`No comparison plan available`; если предыдущего комментария нет —
`First plan for this pull request`. Когда инфраструктура не менялась,
соответствующая секция пишет `No infrastructure changes ...`.

Ограничения diff: значения, неизвестные до apply (например,
`metadata_startup_script`, содержащий ещё не созданный статический IP), в diff
не попадают. Формат плана зависит от версии Terraform и провайдера, поэтому
после обновления версий первый diff может быть шумным. Полный план в
комментарии обрезается после 40 000 символов, каждый diff — после 15 000;
полные версии лежат в артефактах.


Что это даёт: видно, какие ресурсы будут созданы, какие поля изменятся и
сколько ресурсов в diff. Чего это не даёт: не проверяет drift, реальные права
и квоты и не заменяет plan против настоящего проекта. Перед `apply` всё равно
нужен `make plan` с реальным backend и кредами.

### Отчёт по каждому запуску

Job `report` запускается всегда (`if: always()`), даже если предыдущие gate'ы
упали, и пишет Markdown-отчёт в GitHub Job Summary — он виден на странице
запуска: **Actions → нужный run → Summary**.

Что в отчёте:

- общий вердикт: все gate'ы прошли или что-то упало;
- таблица по каждому gate'у: Format, Version, Terraform plan, diff против
  `main` и против предыдущего запуска, тесты на Terraform 1.9.8 и 1.15.6,
  TFLint, Checkov;
- фактический результат тестов из логов, например `Success! 4 passed, 0 failed`;
- сводка плана, например `Plan: 13 to add, 0 to change, 0 to destroy`;
- diff против `main` и предыдущего запуска: `4 added, 2 removed`,
  `no comparison plan` или `no previous plan`;
- внизу отчёта — раскрывающийся блок с самим unified diff (до 30 000 символов),
  ниже таблицы проверок и выше строки с commit.
- commit, ref, событие, автор и ссылка на запуск.

Логи тестов и план загружаются артефактами `terraform-test-*` и
`terraform-plan`, поэтому отчёт показывает результат, даже если соответствующая
job упала. Сам отчёт не блокирует merge: он только агрегирует статусы, решение
принимается по красным/зелёным job'ам выше.

## Процесс изменений: только через pull request

`main` защищён: прямой push, force-push и удаление ветки запрещены. Любое
изменение проходит через PR, даже если это одна строка в README.

1. Создать ветку с префиксом `feat/`, `fix/`, `chore/` или `docs/`.
2. Сделать коммит на английском в формате Conventional Commits.
3. Открыть PR: `gh pr create --fill`.
4. Дождаться зелёных обязательных checks.
5. Смержить squash-merge и удалить ветку.

Обязательные checks:

- `Format`
- `Version and changelog`
- `Terraform plan`
- `Validate and test (Terraform 1.9.8)`
- `Validate and test (Terraform 1.15.6)`
- `TFLint`
- `Security scan (Checkov)`

`Verification report` — информационный job: он не блокирует merge, но
показывает сводку по всем gate'ам в Summary запуска.

Защита ветки воспроизводится скриптом (нужны права admin на репозиторий):

```bash
./scripts/setup-branch-protection.sh
```

## Версионирование и CHANGELOG

- `VERSION` — текущая версия в semver.
- `CHANGELOG.md` — английский, формат Keep a Changelog.
- Каждый merge в `main` — один squash-commit, поэтому patch-версия растёт на
  единицу: `0.0.1` → `0.0.2` → `0.0.3`.
- `make version-bump` поднимает patch и напоминает добавить запись.
- CI job `Version and changelog` требует ровно `+1` patch к `origin/main` и
  наличие заголовка `## [x.y.z]` в `CHANGELOG.md`.
- `terraform output module_version` отдаёт версию конфигурации.

Порядок для каждого изменения:

```bash
make version-bump
# добавить секцию ## [x.y.z] - YYYY-MM-DD в CHANGELOG.md на английском
make verify
```

## Релизы и теги

Makefile использует тот же подход, что и в других репозиториях: последний тег
берётся через `git describe --tags --abbrev=0`, а версия релиза — из `VERSION`.

| Команда | Что делает |
|---|---|
| `make version` | Показывает последний tag и значение из `VERSION` |
| `make tag` | Создаёт аннотированный тег `v$(VERSION)` и пушит его |
| `make release` | То же плюс GitHub Release с notes из `CHANGELOG.md` |

Требования к `make release`:

- текущая ветка `main`, working tree чистый;
- `main` совпадает с `origin/main`;
- `gh` авторизован;
- для `VERSION` есть секция в `CHANGELOG.md`;
- тег ещё не существует.

```bash
make version
make release
# Pushed annotated tag v0.0.1.
# https://github.com/.../releases/tag/v0.0.1
```

Скрипт `scripts/release.sh` идемпотентен по тегу: если тег уже запушен, но
релиза нет, повторный `make release` создаст только GitHub Release. Если
существует и тег, и релиз — команда завершится ошибкой.

## Checkov: блокирующая проверка и исключения

`security` — обязательный job. Любая новая находка Checkov валит PR. Два
правила исключены в `.checkov.yaml`, и каждое исключение — осознанное решение:

| Правило | Почему исключено |
|---|---|
| `CKV_GCP_40` | Публичный IP — это и есть endpoint WireGuard и единственная точка входа SSH. Адрес статический, доступ ограничен firewall и OS Login. Убрать IP = убрать VPN. |
| `CKV_GCP_38` | CSEK признан Google устаревшим. Диски шифруются Google-managed ключами; customer-supplied keys в задачу не входили. |

Правила работы с исключениями:

1. Новый `skip-check` добавляется только вместе с причиной в этом файле и в
   описании PR.
2. Точечное исключение предпочтительнее baseline: baseline скрывает находку,
   но не объясняет решение.
3. Если находка реальная, исправляется конфигурация, а не сканер.
4. Локальный прогон:

```bash
uv run --with 'checkov>=3,<4' checkov -d . --config-file .checkov.yaml
```

Ожидаемый результат: `Failed checks: 0`.

## Agentic workflow

Пайплайн и правила работы агента описаны в
[docs/agentic-workflow.md](docs/agentic-workflow.md). Коротко:

1. Агент делает минимальный diff и не трогает несвязанные ресурсы.
2. `make verify` — обязательный gate: fmt, validate, mocked `terraform test`.
3. Сканеры (`tflint`, `checkov`, `trivy`, `gitleaks`) запускаются, если
   установлены; в CI добавляются отдельными шагами.
4. `terraform plan` читается человеком: destroy/replace stateful-ресурсов
   требуют отдельного подтверждения.
5. `apply` — только по сохранённому `tfplan`, вручную или из защищённого
   pipeline. Автоматического apply после merge нет.

## Ограничения текущей итерации

- Одна VM, без HA и без autoscaling. При потере зоны VPN недоступен.
- Нет Cloud NAT: исходящий трафик идёт через внешний IP самой VM.
- Нет автоматической ротации клиентских ключей: пересоздание VM генерирует
  новые ключи.
- Нет IPv6 внутри туннеля.
- Нет backup/snapshot policy: конфиги восстанавливаются из Secret Manager, но
  история версий секрета ограничена настройками проекта.

## Стоимость

Основные статьи: e2-micro, 20 GB pd-balanced, статический external IP.
Для e2-micro в `europe-central2` ориентир — единицы долларов в месяц при
постоянной работе. Точный расчёт: `gcloud billing` или
[Cloud Pricing Calculator](https://cloud.google.com/products/calculator).

## Удаление

```bash
# 1. Добавить в envs/prod/terraform.tfvars строку
#    deletion_protection = false
# 2. Применить изменение
make plan && make apply
# 3. Удалить остальное
make destroy
```

State bucket и Secret Manager версии удаляются отдельно, вручную.
