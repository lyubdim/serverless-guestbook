# Serverless Guestbook

Простая гостевая книга без аутентификации для бонусного задания курса. Приложение разворачивается в Yandex Cloud на serverless-сервисах и остается доступным по HTTPS через служебный домен API Gateway.

## Текущий статус

Приложение развернуто в Yandex Cloud на serverless-инфраструктуре.

- Приложение: <https://d5d5aflltaku6uqcjvj1.y3q8o1jq.apigw.yandexcloud.net>
- Каталог Yandex Cloud: <https://console.yandex.cloud/folders/b1gpd5k5on35lii7agu3>
- Репозиторий: <https://github.com/lyubdim/serverless-guestbook>

Скрипты без `-Apply` работают в dry-run режиме и не создают ресурсы.

## Что используется

- Object Storage хранит статический frontend (`index.html`, `styles.css`, `app.js`).
- API Gateway отдает frontend и проксирует API-запросы.
- Cloud Functions содержит backend API. У функции две версии с тегами `replica-a` и `replica-b`.
- API Gateway настроен как canary release: 50% запросов идут в `replica-a`, 50% в `replica-b`.
- Serverless YDB хранит сообщения гостевой книги.

В UI видны:

- версия frontend: `v1.0.0`;
- версия backend: `v1.0.0`;
- backend replica: `a` или `b`.

## Структура

```text
app/frontend/        статический интерфейс
app/function/        Python Cloud Function
infra/               шаблон API Gateway и YDB schema
scripts/             PowerShell-скрипты развертывания
dist/                локальное состояние и сгенерированные файлы, не коммитится
```

## Требования

- Yandex Cloud CLI (`yc`) должен быть установлен и инициализирован.
- В текущем профиле `yc` должен быть выбран нужный cloud/folder.
- PowerShell 7 или Windows PowerShell.

Если `yc` лежит не в `PATH`, укажите путь:

```powershell
$env:YC_PATH = "C:\path\to\yc.exe"
```

## Развертывание

Сначала можно посмотреть план без создания ресурсов:

```powershell
.\scripts\deploy-all.ps1
```

Создать/обновить инфраструктуру:

```powershell
.\scripts\deploy-all.ps1 -Apply
```

Если Windows запрещает запуск `.ps1`, используйте такой формат:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-all.ps1 -Apply
```

Перед будущим развертыванием можно выполнить локальные проверки:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-local.ps1
```

После успешного выполнения скрипт выведет:

- ссылку на приложение;
- ссылку на каталог в Yandex Cloud.

Локальное состояние сохраняется в `dist/state.json`.

## Обновление frontend

```powershell
.\scripts\update-frontend.ps1 -Apply
```

## Обновление Cloud Functions

Скрипт создает две новые версии функции и назначает им теги `replica-a` и `replica-b`:

```powershell
.\scripts\update-functions.ps1 -Apply
```

## Создание схемы YDB

Схема описана в `infra/schema.yql`. Для применения используется специальный режим функции:

```powershell
.\scripts\create-ydb-schema.ps1 -Apply
```

## Serverless Containers

Это приложение использует Cloud Functions, а не Serverless Containers. Для полноты в репозитории есть скрипт:

```powershell
.\scripts\update-containers.ps1
```

Он явно фиксирует, что container-часть в данной реализации не используется.

## Доступ проверяющему

Сначала добавьте `digisturm@yandex.ru` в организацию через консоль Yandex Cloud. Затем можно выдать роли командой:

```powershell
.\scripts\grant-reviewer-access.ps1 -ReviewerLogin "digisturm@yandex.ru" -Apply
```

Скрипт выдает:

- `resource-manager.clouds.member` на cloud;
- `admin` на folder.

## Что отправлять на проверку

После deploy можно распечатать готовые поля для формы:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\print-submission-info.ps1
```

Ссылка на каталог:

```text
https://console.yandex.cloud/folders/b1gpd5k5on35lii7agu3
```

Ссылка на приложение:

```text
https://d5d5aflltaku6uqcjvj1.y3q8o1jq.apigw.yandexcloud.net
```

Комментарий:

```text
Приложение: serverless-гостевая книга без аутентификации.
Frontend лежит в Object Storage и отдается через API Gateway. В UI показана версия frontend.
Backend реализован на Yandex Cloud Functions: две версии функции с тегами replica-a и replica-b.
API Gateway настроен через canary release 50/50, поэтому при обновлении/нескольких запросах видны разные backend replica.
Данные сообщений сохраняются в Serverless YDB.
Скрипты PowerShell для развертывания и обновления лежат в scripts/.
```

## Очистка

Обычно для бонусного задания приложение оставляют работать. Если ресурсы больше не нужны:

```powershell
.\scripts\cleanup.ps1 -Apply
```
