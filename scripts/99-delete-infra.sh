#!/usr/bin/env bash
# Apaga TODA a infraestrutura da entrega de DevOps (o Resource Group inteiro). Use só depois de 30/11.
# Não toca em nada fora de $RESOURCE_GROUP (o deploy da entrega de Java fica intacto).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_vars RESOURCE_GROUP
require_az
read -r -p "Digite o nome do Resource Group ($RESOURCE_GROUP) para apagar: " RESPOSTA
[ "$RESPOSTA" = "$RESOURCE_GROUP" ] || { echo "Cancelado."; exit 1; }
az group delete --name "$RESOURCE_GROUP" --yes --no-wait
echo "Exclusão iniciada (leva alguns minutos). Acompanhe: az group show -n $RESOURCE_GROUP"
