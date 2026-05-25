# GitHub publish

Репозиторий уже подготовлен локально. Облачные ресурсы при публикации на GitHub не создаются.

## Вариант 1: создать пустой репозиторий на GitHub вручную

1. Откройте GitHub.
2. Создайте новый пустой репозиторий, например `serverless-guestbook`.
3. Не добавляйте README, `.gitignore` и license через GitHub, потому что они уже есть локально.
4. Скопируйте HTTPS URL репозитория.
5. Выполните из папки проекта:

```powershell
git remote add origin https://github.com/lyubdim/serverless-guestbook.git
git branch -M main
git push -u origin main
```

## Вариант 2: через GitHub CLI

Если установлен и авторизован `gh`:

```powershell
gh auth status
gh repo create serverless-guestbook --private --source . --remote origin --push
```

Для проверки курса чаще удобнее публичный репозиторий:

```powershell
gh repo create serverless-guestbook --public --source . --remote origin --push
```

## Текущее состояние

Локальный первый коммит:

```text
79071ea Initial serverless guestbook
```

В репозитории нет IAM-токенов, ключей сервисных аккаунтов, паролей или созданных cloud state-файлов.
