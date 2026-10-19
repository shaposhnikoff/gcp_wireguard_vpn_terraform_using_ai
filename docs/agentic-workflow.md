# Agentic workflow для Terraform

Документ описывает, как в этом репозитории выглядит разработка инфраструктуры
агентом: какие шаги агент выполняет сам, где обязательна проверка, и что
запрещено автоматизировать.

## Роли

| Роль | Задача | Артефакт |
|---|---|---|
| Planner | разложить запрос на ресурсы, риски, acceptance criteria | этот файл, `tasks/todo.md` |
| Implementer | минимальный diff в HCL и шаблонах | `*.tf`, `templates/` |
| Reviewer | проверить план, тесты, безопасность, откат | `plan.json`, результаты `make verify` |

В одном запуске агент может выполнять роли последовательно, но не должен
смешивать реализацию и финальное ревью в один «самопроверенный» шаг.

## Цикл

```text
запрос
  -> уточнение параметров: проект, регион, CIDR, VPN-стек, state
  -> planner: список ресурсов и рисков
  -> implementer: HCL + шаблон + тесты
  -> gate 1: fmt / validate / tflint
  -> gate 2: terraform test с mock_provider
  -> gate 3: security scanners
  -> gate 4: plan + review diff
  -> apply сохранённого плана
  -> smoke check: SSH, wg show, secret
```

## Gate'ы

| Gate | Команда | Блокирует |
|---|---|---|
| Форматирование | `terraform fmt -check -recursive` | merge |
| Схема и ссылки | `terraform validate` | merge |
| Провайдер-специфичные ошибки | `tflint --recursive` | merge |
| Поведение модуля | `terraform test` | merge |
| Политики безопасности | `checkov`, `trivy config`, `gitleaks` | merge при high/critical, кроме документированных исключений |
| Изменения в облаке | `terraform plan -out=tfplan` | apply |
| Стоимость | `infracost diff` | порог бюджета |

`make verify` объединяет первые четыре gate'а и опционально сканеры.
`scripts/security.sh` запускает сканеры отдельно.

## Правила для AI-сгенерированного кода

1. Агент не выдумывает аргументы провайдера. Спорные поля сверяются со схемой:
   `terraform providers schema -json`.
2. Версии провайдеров и образов фиксируются диапазоном или точным тегом.
3. Секреты не попадают в HCL, `tfvars`, state и логи. Для секретов —
   Secret Manager и runtime-генерация.
4. Один diff — одна цель. Рефакторинг и изменение поведения не смешиваются.
5. Каждый ресурс должен иметь объяснение: зачем он нужен и что будет при
   удалении.
6. `apply` и `destroy` не запускаются автоматически. Только по сохранённому
   плану и после явного подтверждения.
7. Если план содержит destroy или replace stateful-ресурса, агент обязан
   остановиться и запросить решение человека.

## Что проверяется в plan

- `terraform plan -detailed-exitcode`: 0 — изменений нет, 2 — есть, 1 — ошибка.
- `terraform show -json tfplan` + `jq`/`conftest`:
  - нет неожиданных `delete` и `replace`;
  - не меняется `deletion_protection`, `force_destroy`, `prevent_destroy`;
  - не открываются порты вне разрешённого набора;
  - не появляются ресурсы в неразрешённых регионах.
- `infracost diff` для оценки стоимости.

## Минимальный сценарий сессии

```bash
make verify                 # локальные gate'ы
make plan                   # сохранить план
terraform show tfplan       # прочитать diff
make apply                  # применить ровно этот план
terraform output            # проверить результат
```

## Явные не-цели

- Автоматический apply после merge.
- Автоматическое изменение IAM и organization policies.
- `terraform state mv/rm/import` без backup state.
- Ротация ключей без окна обслуживания и проверки клиентов.
