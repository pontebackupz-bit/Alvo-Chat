#!/usr/bin/env bash
# Atualiza o AlvoChat no servidor:
#   backup do banco -> git pull -> build -> subir -> migração -> healthcheck
#
# Uso (na pasta do projeto):   ./deploy.sh
# Opções por variável:         BRANCH=outra-branch REMOTE=origin SKIP_BACKUP=1 ./deploy.sh
#
# O deploy roda desacoplado do terminal (nohup): se o SSH cair, ele continua.
# Para acompanhar depois:      tail -f ~/alvochat-deploy.log
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

COMPOSE_FILE=docker-compose.production.yaml
export COMPOSE_PROJECT_NAME=crm-omnichannel
LOG_FILE="$HOME/alvochat-deploy.log"
BACKUP_DIR="$HOME/alvochat-backups"
BACKUPS_TO_KEEP=14
HEALTH_URL="http://localhost:8069/api"
HEALTH_TIMEOUT=300

if [ -z "${ALVOCHAT_DEPLOY_DETACHED:-}" ]; then
  : > "$LOG_FILE"
  ALVOCHAT_DEPLOY_DETACHED=1 nohup "$0" "$@" >> "$LOG_FILE" 2>&1 &
  deploy_pid=$!
  echo "Deploy iniciado (PID $deploy_pid). Log: $LOG_FILE"
  echo "Pode fechar o terminal com Ctrl+C: o deploy continua."
  tail -n +1 -f --pid="$deploy_pid" "$LOG_FILE"
  wait "$deploy_pid" 2>/dev/null || exit $?
  exit 0
fi

compose() { docker compose -f "$COMPOSE_FILE" "$@"; }
step() { printf '\n==> [%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
fail() { printf '\nERRO: %s\n' "$*"; exit 1; }
env_value() { grep -E "^$1=" .env | tail -n 1 | cut -d= -f2- | tr -d "\"'"; }

step "Conferindo o ambiente"
command -v docker > /dev/null || fail "docker não encontrado."
[ -f "$COMPOSE_FILE" ] || fail "$COMPOSE_FILE não encontrado em $(pwd)."
[ -f .env ] || fail ".env não encontrado em $(pwd)."
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  git status --short --untracked-files=no
  fail "há arquivos alterados no servidor. Salve-os (git stash) antes do deploy."
fi

# Another Compose project holding port 8069 means the wrong project name was used before.
other_project=$(docker ps --filter publish=8069 --format '{{.Label "com.docker.compose.project"}}' | grep -v "^$COMPOSE_PROJECT_NAME\$" || true)
if [ -n "$other_project" ]; then
  fail "a porta 8069 está com o projeto '$other_project'. Pare-o com: docker compose -p $other_project -f $COMPOSE_FILE down (sem -v)."
fi

REMOTE=${REMOTE:-origin}
BRANCH=${BRANCH:-$(git rev-parse --abbrev-ref HEAD)}
git remote get-url "$REMOTE" > /dev/null 2>&1 || fail "remote '$REMOTE' não existe. Remotes: $(git remote | tr '\n' ' ')"

if [ -z "${SKIP_BACKUP:-}" ] && [ -n "$(compose ps -q postgres 2> /dev/null)" ]; then
  step "Backup do banco"
  mkdir -p "$BACKUP_DIR"
  db_user=$(env_value POSTGRES_USERNAME); db_user=${db_user:-postgres}
  db_name=$(env_value POSTGRES_DATABASE); db_name=${db_name:-chatwoot_production}
  backup_file="$BACKUP_DIR/alvochat-$(date '+%Y%m%d-%H%M%S').dump"
  compose exec -T postgres pg_dump -U "$db_user" -Fc "$db_name" > "$backup_file" \
    || { rm -f "$backup_file"; fail "o backup falhou; deploy cancelado."; }
  echo "Backup salvo em $backup_file ($(du -h "$backup_file" | cut -f1))"
  ls -1t "$BACKUP_DIR"/alvochat-*.dump 2> /dev/null | tail -n +$((BACKUPS_TO_KEEP + 1)) | xargs -r rm -f
fi

step "Atualizando o código ($REMOTE/$BRANCH)"
previous_commit=$(git rev-parse --short HEAD)
git fetch "$REMOTE" "$BRANCH"
git checkout "$BRANCH"
git merge --ff-only FETCH_HEAD || fail "o servidor tem commits locais que não estão em $REMOTE/$BRANCH."
current_commit=$(git rev-parse --short HEAD)
echo "Versão: $previous_commit -> $current_commit"
git log --oneline "$previous_commit..$current_commit" | head -n 20

step "Gerando as imagens"
compose build

step "Subindo os containers"
compose up -d --remove-orphans

step "Aguardando o Rails responder"
elapsed=0
until curl -fsS -o /dev/null "$HEALTH_URL"; do
  [ "$elapsed" -ge "$HEALTH_TIMEOUT" ] && { compose logs --tail=80 rails; fail "o Rails não respondeu em ${HEALTH_TIMEOUT}s."; }
  sleep 5
  elapsed=$((elapsed + 5))
done
echo "Rails no ar após ${elapsed}s."

step "Rodando as migrações"
compose exec -T rails bundle exec rails db:chatwoot_prepare

step "Healthcheck final"
curl -fsS "$HEALTH_URL" && echo
compose ps

step "Deploy concluído: $current_commit. Abra o sistema com Ctrl+F5."
