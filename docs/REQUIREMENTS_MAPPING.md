# Requirements mapping

Карта соответствия бонусному заданию.

| Требование | Как закрыто в проекте |
| --- | --- |
| Веб-приложение без аутентификации | Гостевая книга, входа и пользователей нет. |
| Статический frontend доступен из интернета | `app/frontend/` загружается в Object Storage и отдается через API Gateway. |
| В UI видна версия frontend | `app/frontend/app.js`: `FRONTEND_VERSION = "1.0.0"`. |
| Backend на serverless-технологиях | `app/function/index.py` разворачивается в Yandex Cloud Functions. |
| Есть реплики backend | `scripts/update-functions.ps1` создает две версии функции с тегами `replica-a` и `replica-b`. |
| В UI видна версия backend | Backend возвращает `backendVersion`, frontend показывает его в статусном блоке. |
| Видно, на какую replica попал запрос | Backend возвращает `backendReplica`, frontend показывает `a` или `b`. |
| Разные реплики скрыты за API Gateway | `infra/api-gateway.yml.template` использует переменную `backend.tag`; `scripts/deploy-all.ps1` настраивает canary `50/50`. |
| Данные сохраняются в Serverless YDB | Таблица `messages`, работа через Python SDK `ydb`. |
| Публичный HTTPS-доступ | После deploy приложение доступно по служебному домену API Gateway `https://*.apigw.yandexcloud.net`. |
| Скрипт обновления Serverless Functions | `scripts/update-functions.ps1`. |
| Скрипт обновления Serverless Containers | `scripts/update-containers.ps1`; в этой реализации backend выбран на Functions, поэтому контейнеры явно не используются. |
| Скрипт создания схемы YDB | `scripts/create-ydb-schema.ps1`, запускает функцию в режиме `maintenanceAction=migrate`. |
| Скрипт полного развертывания | `scripts/deploy-all.ps1`. |
| Доступ проверяющему | `scripts/grant-reviewer-access.ps1` выдает роли после добавления учетной записи в организацию. |
| Репозиторий без секретов | `.gitignore` исключает `dist/`, zip-пакеты, `.env`, кэш Python. |
| Безопасный dry-run | Все скрипты без `-Apply` работают в dry-run режиме. |

## Текущее состояние

1. Репозиторий опубликован: <https://github.com/lyubdim/serverless-guestbook>.
2. Приложение развернуто: <https://d5d5aflltaku6uqcjvj1.y3q8o1jq.apigw.yandexcloud.net>.
3. Serverless YDB schema создана.
4. API Gateway проверен: запросы попадают в `replica-a` и `replica-b`.
5. Остается добавить проверяющего в организацию и выдать роли, если это еще не сделано.
