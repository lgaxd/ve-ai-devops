#!/usr/bin/env bash
# Funções comuns dos scripts de infraestrutura (rodar no WSL ou Git Bash, com a Azure CLI logada).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# tr -d '\r': o editor do Windows grava CRLF e o \r viraria parte do valor das variáveis
# shellcheck source=/dev/null
if [ -f "$ROOT/.env.azure" ]; then set -a; source <(tr -d '\r' < "$ROOT/.env.azure"); set +a; fi

require_vars() {
  local missing=0
  for v in "$@"; do
    if [ -z "${!v:-}" ]; then echo "ERRO: defina $v no .env.azure (ou no Variable Group)"; missing=1; fi
  done
  [ "$missing" = 0 ] || exit 1
}

require_az() {
  command -v az >/dev/null || { echo "ERRO: Azure CLI não encontrada (az)."; exit 1; }
  az account show --query "{assinatura:name, usuario:user.name}" --output table \
    || { echo "ERRO: rode 'az login' primeiro."; exit 1; }
}

require_sqlcmd() {
  command -v sqlcmd >/dev/null || {
    echo "ERRO: sqlcmd não encontrado. No Ubuntu/WSL:"
    echo "  curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc"
    echo "  sudo add-apt-repository \"\$(wget -qO- https://packages.microsoft.com/config/ubuntu/\$(lsb_release -rs)/prod.list)\""
    echo "  sudo apt-get update && sudo apt-get install -y sqlcmd"
    exit 1
  }
}

web_host() { az webapp show --resource-group "$RESOURCE_GROUP" --name "$WEB_APP_NAME" --query defaultHostName --output tsv; }

sql_host() { echo "${SQL_SERVER_NAME}.database.windows.net"; }

# URL JDBC do Azure SQL (TLS obrigatório, certificado validado)
jdbc_url() {
  echo "jdbc:sqlserver://$(sql_host):1433;database=${SQL_DATABASE};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30"
}
