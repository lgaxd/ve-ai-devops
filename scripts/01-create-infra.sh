#!/usr/bin/env bash
# =============================================================================
# Vê AI · cria (ou reaproveita) toda a infraestrutura na Azure, só com Azure CLI:
#   1. Resource Group
#   2. Azure SQL: servidor lógico + banco "veai" (Basic, 5 DTU)
#   3. Firewall do Azure SQL: serviços do Azure (o Web App) + o seu IP (para os SELECTs do vídeo)
#   4. Usuário da aplicação no banco (contained user; a API não usa o administrador)
#   5. App Service Plan Linux B1
#   6. Web App Java 21 + App Settings iniciais
#
# O schema (tabelas, índices e seed) NÃO é criado aqui: o Flyway da API aplica o
# db/migration/sqlserver/V1__schema.sql (o mesmo DDL de scripts/script-bd.sql) no primeiro start.
# Pode rodar de novo sem medo: cada passo só cria o que ainda não existe.
#
# Uso (WSL ou Git Bash):  cp .env.azure.example .env.azure  →  preencha  →  az login  →
#                         bash scripts/01-create-infra.sh
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_vars LOCATION RESOURCE_GROUP APP_SERVICE_PLAN WEB_APP_NAME SQL_SERVER_NAME SQL_DATABASE \
             SQL_ADMIN_USER SQL_ADMIN_PASSWORD DB_USER DB_PASSWORD JWT_SECRET OPENAI_API_KEY RABBITMQ_URL
require_sqlcmd
echo "==> Assinatura Azure em uso"
require_az
az provider register --namespace Microsoft.Sql --wait --output none
az provider register --namespace Microsoft.Web --wait --output none

falha_regiao() {
  echo "ERRO: a criação falhou em $LOCATION."
  echo "  Se a mensagem acima fala de política/região restrita ('RequestDisallowedByAzure' ou"
  echo "  'not available in this region'), troque LOCATION=southafricanorth no .env.azure,"
  echo "  apague o grupo vazio (az group delete -n $RESOURCE_GROUP --yes) e rode de novo."
  exit 1
}

echo "==> 1/6 Resource Group $RESOURCE_GROUP ($LOCATION)"
RG_LOCATION="$(az group show --name "$RESOURCE_GROUP" --query location --output tsv 2>/dev/null || true)"
if [ -z "$RG_LOCATION" ]; then
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
elif [ "$RG_LOCATION" != "$LOCATION" ]; then
  echo "    AVISO: o Resource Group já existe em $RG_LOCATION; os recursos abaixo vão para $LOCATION."
fi

echo "==> 2/6 Azure SQL: servidor $SQL_SERVER_NAME e banco $SQL_DATABASE (Basic, 5 DTU, 2 GB)"
if az sql server show -g "$RESOURCE_GROUP" -n "$SQL_SERVER_NAME" --output none 2>/dev/null; then
  echo "    servidor já existe, reaproveitando"
else
  az sql server create -g "$RESOURCE_GROUP" -n "$SQL_SERVER_NAME" -l "$LOCATION" \
    --admin-user "$SQL_ADMIN_USER" --admin-password "$SQL_ADMIN_PASSWORD" \
    --minimal-tls-version 1.2 --output none || falha_regiao
fi
if az sql db show -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" -n "$SQL_DATABASE" --output none 2>/dev/null; then
  echo "    banco já existe, reaproveitando"
else
  # Basic é sempre ligado (o serverless "free" pausa sozinho e derruba o health check da Release)
  az sql db create -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" -n "$SQL_DATABASE" \
    --service-objective Basic --backup-storage-redundancy Local --output none || falha_regiao
fi
echo "    Azure SQL: $(sql_host),1433 / $SQL_DATABASE"

echo "==> 3/6 Firewall do Azure SQL"
# 0.0.0.0 - 0.0.0.0 é a regra especial "permitir serviços do Azure": é por ela que o Web App acessa o banco
az sql server firewall-rule create -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" -n AllowAzureServices \
  --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 --output none
CLIENT_IP="${CLIENT_IP:-$(curl -s https://api.ipify.org || true)}"
if [ -n "$CLIENT_IP" ]; then
  az sql server firewall-rule create -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" -n AllowClientIP \
    --start-ip-address "$CLIENT_IP" --end-ip-address "$CLIENT_IP" --output none
  echo "    liberados: serviços do Azure e o seu IP ($CLIENT_IP)"
else
  echo "    serviços do Azure liberados; seu IP não foi detectado (defina CLIENT_IP e rode de novo)"
fi

echo "==> 4/6 Usuário da aplicação ($DB_USER) no banco $SQL_DATABASE"
sql_admin() { # sql_admin <sql>
  sqlcmd -S "tcp:$(sql_host),1433" -d "$SQL_DATABASE" -U "$SQL_ADMIN_USER" -P "$SQL_ADMIN_PASSWORD" -b -Q "$1"
}
# a regra de firewall pode levar alguns segundos para valer
for i in $(seq 1 12); do
  sql_admin "SELECT 1" >/dev/null 2>&1 && break
  [ "$i" = 12 ] && { echo "ERRO: não consegui conectar ao Azure SQL com o administrador (firewall, IP ou senha)."; exit 1; }
  echo "    aguardando o firewall liberar o seu IP ($i/12)..."; sleep 10
done
# Contained user: existe só dentro do banco veai. db_owner deixa o Flyway criar e alterar as tabelas,
# sem nenhum poder no servidor (não enxerga outros bancos nem pode criar logins).
sql_admin "IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$DB_USER')
             CREATE USER [$DB_USER] WITH PASSWORD = N'$DB_PASSWORD';
           ELSE
             ALTER USER [$DB_USER] WITH PASSWORD = N'$DB_PASSWORD';
           ALTER ROLE db_owner ADD MEMBER [$DB_USER];" >/dev/null
echo "    usuário $DB_USER pronto"

echo "==> 5/6 App Service Plan $APP_SERVICE_PLAN (Linux B1)"
az appservice plan show -g "$RESOURCE_GROUP" -n "$APP_SERVICE_PLAN" --output none 2>/dev/null \
  || az appservice plan create -g "$RESOURCE_GROUP" -n "$APP_SERVICE_PLAN" -l "$LOCATION" --is-linux --sku B1 --output none \
  || falha_regiao

echo "==> 6/6 Web App $WEB_APP_NAME (Java 21) e App Settings"
az webapp show -g "$RESOURCE_GROUP" -n "$WEB_APP_NAME" --output none 2>/dev/null \
  || az webapp create -g "$RESOURCE_GROUP" -p "$APP_SERVICE_PLAN" -n "$WEB_APP_NAME" \
       --runtime "JAVA:21-java21" --https-only true --output none
az webapp config set -g "$RESOURCE_GROUP" -n "$WEB_APP_NAME" --always-on true --output none
az webapp log config -g "$RESOURCE_GROUP" -n "$WEB_APP_NAME" --application-logging filesystem \
  --docker-container-logging filesystem --level information --output none

# Os mesmos App Settings que a Release grava a cada deploy (aqui só para o primeiro start)
DB_URL="$(jdbc_url)"; export DB_URL
bash "$(dirname "${BASH_SOURCE[0]}")/app-settings.sh"

echo
echo "Infraestrutura pronta."
echo "  Web App  : https://$(web_host)   (Swagger: /swagger-ui.html)"
echo "  Azure SQL: $(sql_host) / $SQL_DATABASE"
echo
echo "Cadastre no Variable Group 'veai-devops-secrets' (Pipelines > Library), marcando os segredos como secretos:"
echo "  DB_URL = $DB_URL"
echo "  DB_USER, DB_PASSWORD, JWT_SECRET, OPENAI_API_KEY, RABBITMQ_URL, SMOKE_EMAIL, SMOKE_SENHA (do .env.azure)"
echo "  GITHUB_PAT e GITHUB_REPO (espelho no GitHub)"
az resource list -g "$RESOURCE_GROUP" --query "[].{recurso:name, tipo:type}" --output table
