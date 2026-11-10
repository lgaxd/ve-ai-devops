#!/usr/bin/env bash
# =============================================================================
# Smoke test da API já implantada (stage SmokeTest da Release). Só leitura: não grava nada no banco,
# para o Azure SQL ficar limpo para a demonstração do CRUD com SELECT.
#   1. /health público responde UP
#   2. rota protegida sem token responde 401
#   3. login da cidadã de demonstração (seed)
#   4. /health com token mostra db, rabbit e openai UP
#   5. GET /regioes e GET /usuarios/me com o token
# Variáveis: RESOURCE_GROUP + WEB_APP_NAME (ou BASE_URL), SMOKE_EMAIL, SMOKE_SENHA.
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_vars SMOKE_EMAIL SMOKE_SENHA
if [ -z "${BASE_URL:-}" ]; then
  require_vars RESOURCE_GROUP WEB_APP_NAME
  BASE_URL="https://$(web_host)"
fi

TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
FAIL=0

# chamar MÉTODO CAMINHO ESPERADO [TOKEN] [JSON] -> grava o corpo em $TMP
# Repete até 6 vezes (10 s) em 000/502/503/504: reinício ou cold start são transitórios.
chamar() {
  local metodo="$1" caminho="$2" esperado="$3" token="${4:-}" corpo="${5:-}" code tentativa
  local args=(-s -o "$TMP" -w "%{http_code}" --max-time 30 -X "$metodo" "$BASE_URL$caminho")
  [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
  [ -n "$corpo" ] && args+=(-H "Content-Type: application/json" -d "$corpo")
  for tentativa in 1 2 3 4 5 6; do
    code="$(curl "${args[@]}" || true)"
    case "$code" in
      000|502|503|504) [ "$code" = "$esperado" ] && break
                       echo "    ($metodo $caminho -> HTTP $code, tentativa $tentativa/6; aguardando 10 s)"; sleep 10 ;;
      *) break ;;
    esac
  done
  if [ "$code" = "$esperado" ]; then echo "PASS $metodo $caminho -> $code"
  else echo "FAIL $metodo $caminho -> $code (esperado $esperado): $(head -c 300 "$TMP")"; FAIL=1; fi
}
campo() { python3 -c "import json,sys; d=json.load(open('$TMP')); print(eval('d' + sys.argv[1]))" "$1"; }

echo "==> Smoke test em $BASE_URL"
chamar GET /health 200
[ "$(campo "['status']")" = "UP" ] || { echo "FAIL /health sem status UP"; FAIL=1; }
chamar GET /relatos/meus 401
chamar POST /auth/login 200 "" "{\"email\":\"$SMOKE_EMAIL\",\"senha\":\"$SMOKE_SENHA\"}"
[ "$FAIL" = 0 ] || { echo "Login falhou; abortando."; exit 1; }
TOKEN="$(campo "['token']")"

chamar GET /health 200 "$TOKEN"
for componente in db rabbit openai; do
  STATUS="$(campo "['components'].get('$componente', {}).get('status')")"
  if [ "$STATUS" = "UP" ]; then echo "PASS componente $componente = UP"
  else echo "FAIL componente $componente = $STATUS"; FAIL=1; fi
done

chamar GET /regioes 200 "$TOKEN"
[ "$(campo "[0]['nome'] if d else ''")" != "" ] || { echo "FAIL /regioes vazio (seed não aplicado?)"; FAIL=1; }
chamar GET /usuarios/me 200 "$TOKEN"
[ "$(campo "['email']")" = "$SMOKE_EMAIL" ] || { echo "FAIL /usuarios/me não é a conta do login"; FAIL=1; }

if [ "$FAIL" = 0 ]; then echo "Smoke test OK"; else echo "Smoke test com falhas"; exit 1; fi
