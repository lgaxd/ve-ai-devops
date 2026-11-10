#!/usr/bin/env bash
# =============================================================================
# Roda SQL no Azure SQL com o sqlcmd (usado no vídeo para provar o CRUD com SELECT).
# Precisa do seu IP liberado no firewall (o script 01 cria a regra AllowClientIP; se o seu IP
# mudou, rode: bash scripts/sql.sh --liberar-ip).
#
#   bash scripts/sql.sh "SELECT TOP 5 id, tipo, status FROM relato ORDER BY id DESC"
#   bash scripts/sql.sh -f database/crud-verification.sql
#   bash scripts/sql.sh --liberar-ip
# Conecta com o usuário da aplicação (DB_USER); --admin no início usa o administrador do servidor.
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_vars SQL_SERVER_NAME SQL_DATABASE

if [ "${1:-}" = "--liberar-ip" ]; then
  require_vars RESOURCE_GROUP
  require_az >/dev/null
  IP="$(curl -s https://api.ipify.org)"
  az sql server firewall-rule create -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" -n AllowClientIP \
    --start-ip-address "$IP" --end-ip-address "$IP" --output none
  echo "IP $IP liberado no firewall do $SQL_SERVER_NAME (pode levar alguns segundos para valer)."
  exit 0
fi

USUARIO="${DB_USER:-}"; SENHA="${DB_PASSWORD:-}"
if [ "${1:-}" = "--admin" ]; then USUARIO="$SQL_ADMIN_USER"; SENHA="$SQL_ADMIN_PASSWORD"; shift; fi
[ -n "$USUARIO" ] && [ -n "$SENHA" ] || { echo "ERRO: defina DB_USER e DB_PASSWORD no .env.azure"; exit 1; }
require_sqlcmd
[ $# -ge 1 ] || { echo "Uso: bash scripts/sql.sh \"SELECT ...\"  |  -f arquivo.sql  |  --liberar-ip"; exit 1; }

# -W tira espaços à direita, -s " | " separa as colunas: saída legível no vídeo
OPCOES=(-S "tcp:$(sql_host),1433" -d "$SQL_DATABASE" -U "$USUARIO" -P "$SENHA" -b -W -s " | ")
if [ "$1" = "-f" ]; then
  sqlcmd "${OPCOES[@]}" -i "$2"
else
  sqlcmd "${OPCOES[@]}" -Q "SET NOCOUNT ON; $1"
fi
