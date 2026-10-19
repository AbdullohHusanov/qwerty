#!/bin/sh
# Установка CA или AS на новый сервер прямо из приватного GitHub:
#   sudo sh bootstrap.sh ca      # сервер CA
#   sudo sh bootstrap.sh as      # сервер AS
#
# Спросит токен GitHub (Settings → Developer settings → Personal access tokens, доступ только на чтение
# к ca-relise / as-relise). Токен нигде не сохраняется: ни в истории, ни в .git/config, ни на диске.
# Скачивает репозиторий во временную папку, запускает new-server/install-<роль>.sh и удаляет скачанное.
# Все переменные установщиков (BANK_NAME, ROOT_DIR, DB_HOST, PORT, ...) передаются как есть: sudo -E ...
set -eu

ROLE=${1:-}
OWNER=${GITHUB_OWNER:-Jas-5808}
BRANCH=${BRANCH:-main}
case "$ROLE" in
  ca) REPO=ca-relise ;;
  as) REPO=as-relise ;;
  *) echo "Укажите роль: sudo sh bootstrap.sh ca  или  sudo sh bootstrap.sh as"; exit 1 ;;
esac

fail() { echo "ОШИБКА: $*"; exit 1; }
[ "$(id -u)" -eq 0 ] || fail "запустите через sudo"
command -v git >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y -qq git ca-certificates >/dev/null; }

# Токен GitHub для скачивания (вставьте между кавычками; пусто — скрипт спросит):
EMBEDDED_TOKEN='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'
TOKEN=${GITHUB_TOKEN:-$EMBEDDED_TOKEN}
if [ -z "$TOKEN" ]; then
  [ -t 0 ] || fail "нужен токен GitHub: запустите в терминале или GITHUB_TOKEN=... sudo -E sh bootstrap.sh $ROLE"
  printf "Токен GitHub (символы не видны): "; stty -echo; read -r TOKEN; stty echo; echo
fi
[ -n "$TOKEN" ] || fail "пустой токен"

WORK=$(mktemp -d /tmp/ozmst-install.XXXXXX)
trap 'rm -rf "$WORK"' EXIT INT TERM
chmod 700 "$WORK"

echo "Скачиваю $OWNER/$REPO ($BRANCH)..."
AUTH=$(printf 'x-access-token:%s' "$TOKEN" | base64 | tr -d '\n')
# Токен передаётся заголовком только этой команде: в URL, .git/config и список процессов git он не попадает.
if ! GIT_TERMINAL_PROMPT=0 git -c credential.helper= -c "http.extraHeader=Authorization: Basic $AUTH" \
     clone -q --depth 1 --branch "$BRANCH" "https://github.com/$OWNER/$REPO.git" "$WORK/repo"; then
  fail "не удалось скачать репозиторий: проверьте токен (доступ к $OWNER/$REPO) и интернет"
fi
unset TOKEN AUTH

INSTALLER="$WORK/repo/new-server/install-$ROLE.sh"
[ -f "$INSTALLER" ] || fail "в репозитории нет new-server/install-$ROLE.sh"
cd "$WORK/repo/new-server"
sh "$INSTALLER"
