#!/usr/bin/env bash
# =============================================================================
# Deploy do JAR no Azure Web App e espera a API (com Azure SQL e RabbitMQ) ficar saudável.
# Usado pela pipeline de Release (AzureCLI@2). Também funciona manualmente:
#   bash scripts/deploy-app.sh target/ve-ai-api.jar
# Segredos (DB_URL, DB_USER, DB_PASSWORD, JWT_SECRET, OPENAI_API_KEY, RABBITMQ_URL) chegam como
# variáveis de ambiente: Variable Group na pipeline, .env.azure no uso local. Nunca ficam no código.
# =============================================================================
set -euo pipefail
DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$DIR/lib.sh"
require_vars RESOURCE_GROUP WEB_APP_NAME
if [ -z "${DB_URL:-}" ] && [ -n "${SQL_SERVER_NAME:-}" ]; then DB_URL="$(jdbc_url)"; export DB_URL; fi

JAR="${1:-$ROOT/target/ve-ai-api.jar}"
[ -f "$JAR" ] || { echo "ERRO: JAR não encontrado: $JAR"; exit 1; }
URL="https://$(web_host)"

echo "==> 1/4 App Settings do $WEB_APP_NAME"
bash "$DIR/app-settings.sh"

echo "==> 2/4 Enviando $(basename "$JAR") para o Web App"
az webapp deploy --resource-group "$RESOURCE_GROUP" --name "$WEB_APP_NAME" \
  --src-path "$JAR" --type jar --track-status false --output none

# O "az webapp deploy" volta ANTES de o app reiniciar com o JAR novo. Se o health check rodasse nesse
# intervalo, a instância ANTIGA responderia 200. Por isso: espera o reinício (o app sai do ar), espera
# voltar e confirma 3 respostas seguidas.
code() { curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL/health" || true; }

echo "==> 3/4 Aguardando o app reiniciar com o JAR novo (até 90 s)"
SAW_RESTART=0
for _ in $(seq 1 45); do
  CODE="$(code)"
  if [ "$CODE" != "200" ]; then SAW_RESTART=1; echo "    reinício detectado (HTTP $CODE)"; break; fi
  sleep 2
done
[ "$SAW_RESTART" = 1 ] || echo "    reinício não observado em 90 s (o app pode já ter reiniciado); seguindo"

echo "==> 4/4 Aguardando $URL/health responder UP (até 10 minutos)"
for i in $(seq 1 60); do
  CODE="$(code)"
  if [ "$CODE" = "200" ]; then
    OK=1
    for _ in 1 2; do sleep 5; [ "$(code)" = "200" ] && OK=$((OK + 1)); done
    if [ "$OK" = 3 ]; then
      echo "API saudável (aplicação + Azure SQL + RabbitMQ + OpenAI): $URL/swagger-ui.html"
      exit 0
    fi
    echo "    instável, aguardando..."
  else
    echo "    tentativa $i/60: HTTP $CODE"
  fi
  sleep 10
done

echo "ERRO: a API não ficou saudável."
echo "  503 = app no ar, mas algum componente fora (Azure SQL: firewall/DB_URL/senha; RabbitMQ: RABBITMQ_URL;"
echo "        OpenAI: OPENAI_API_KEY). Detalhes: faça login e abra /health com o token."
echo "  000 = o app ainda não respondeu. Logs: az webapp log tail -g $RESOURCE_GROUP -n $WEB_APP_NAME"
exit 1
