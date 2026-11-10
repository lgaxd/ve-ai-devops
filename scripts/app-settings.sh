#!/usr/bin/env bash
# Grava as variáveis de ambiente da API (App Settings) no Web App, sem exibir os valores.
# Usado pelo 01-create-infra.sh e pelo deploy-app.sh (Release). Os segredos chegam por variável de
# ambiente: do .env.azure quando roda local, do Variable Group "veai-devops-secrets" na pipeline.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_vars RESOURCE_GROUP WEB_APP_NAME DB_URL DB_USER DB_PASSWORD JWT_SECRET OPENAI_API_KEY RABBITMQ_URL

SETTINGS_FILE="$(mktemp)"
trap 'rm -f "$SETTINGS_FILE"' EXIT
chmod 600 "$SETTINGS_FILE"
python3 - "$SETTINGS_FILE" <<'PY'
import json, os, sys
e = os.environ
json.dump({
    "SPRING_PROFILES_ACTIVE": "azure",          # Azure SQL (application.yml)
    "DB_URL": e["DB_URL"],
    "DB_USER": e["DB_USER"],
    "DB_PASSWORD": e["DB_PASSWORD"],
    "JWT_SECRET": e["JWT_SECRET"],
    "RABBITMQ_URL": e["RABBITMQ_URL"],          # CloudAMQP exclusivo da entrega de DevOps
    "VEAI_IA_PROVEDOR": "openai",
    "OPENAI_API_KEY": e["OPENAI_API_KEY"],
    "VEAI_CORS_ORIGENS": "*",
    "PORT": "8080",
    "WEBSITES_PORT": "8080",
    "WEBSITES_CONTAINER_START_TIME_LIMIT": "600",
    "JAVA_OPTS": "-XX:MaxRAMPercentage=75 -Duser.timezone=America/Sao_Paulo",
}, open(sys.argv[1], "w"))
PY
az webapp config appsettings set --resource-group "$RESOURCE_GROUP" --name "$WEB_APP_NAME" \
  --settings "@$SETTINGS_FILE" --output none
echo "    App Settings gravados em $WEB_APP_NAME (valores não exibidos)"
