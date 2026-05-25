# Pre-deploy checklist

Этот файл нужен, чтобы не поднять ресурсы раньше времени.

## Пока сертификат не получен

- Не запускать команды с `-Apply`.
- Не выдавать доступ проверяющим.
- Не создавать API Gateway, YDB, Object Storage bucket и Cloud Functions.
- Можно спокойно редактировать код, README и скрипты.
- Можно залить репозиторий на GitHub: секретов и токенов в файлах нет.

## Перед развертыванием

1. Проверить, что сертификат/основная часть курса уже закрыта.
2. Убедиться, что выбран правильный каталог:

```powershell
..\tools\yc\yc.exe config get folder-id
```

3. Выполнить dry-run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-all.ps1
```

4. Только после этого создать ресурсы:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-all.ps1 -Apply
```

5. Проверить ссылку приложения, которую выведет скрипт.
6. Добавить `digisturm@yandex.ru` в организацию.
7. Выдать доступ:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\grant-reviewer-access.ps1 -Apply
```

## Что отправить на проверку

- Ссылку на каталог Yandex Cloud.
- Ссылку на GitHub-репозиторий.
- Ссылку на приложение.
- Комментарий из README.
