# Deployment runbook

Краткая памятка по текущему развертыванию и обслуживанию приложения.

## Текущее развертывание

- Приложение: <https://d5d5aflltaku6uqcjvj1.y3q8o1jq.apigw.yandexcloud.net>
- Каталог Yandex Cloud: <https://console.yandex.cloud/folders/b1gpd5k5on35lii7agu3>
- Репозиторий: <https://github.com/lyubdim/serverless-guestbook>

## Проверка

Локальная проверка кода и dry-run deploy:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-local.ps1
```

Проверка backend replicas:

```powershell
$url = "https://d5d5aflltaku6uqcjvj1.y3q8o1jq.apigw.yandexcloud.net"
1..8 | ForEach-Object { Invoke-RestMethod "$url/api/health" }
```

В ответах должны встречаться `backendReplica: a` и `backendReplica: b`.

## Обновление

Обновить frontend в Object Storage:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\update-frontend.ps1 -Apply
```

Обновить обе backend-реплики Cloud Functions:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\update-functions.ps1 -Apply
```

Создать или обновить схему YDB:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\create-ydb-schema.ps1 -Apply
```

Полностью применить инфраструктуру:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-all.ps1 -Apply
```

## Доступ проверяющему

Сначала учетную запись `digisturm@yandex.ru` нужно добавить в организацию через консоль Yandex Cloud. После этого роли можно выдать скриптом:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\grant-reviewer-access.ps1 -Apply
```

Скрипт выдает `resource-manager.clouds.member` на cloud и `admin` на folder.

## Очистка

Обычно это приложение оставляют работать как serverless-портфолио. Если ресурсы больше не нужны:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\cleanup.ps1 -Apply
```
