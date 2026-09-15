#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "uso: $0 <stack> [argumentos do terraform ...]" >&2
  exit 2
fi

STACK="$1"
shift
DIRETORIO="terraform/$STACK"
RESUMO="${GITHUB_STEP_SUMMARY:-/dev/null}"
ERROS=$(mktemp)

terraform -chdir="$DIRETORIO" init -input=false

if ! RECURSOS=$(terraform -chdir="$DIRETORIO" state list 2> "$ERROS"); then
  if ! grep -q "No state file was found" "$ERROS"; then
    cat "$ERROS" >&2
    echo "::error::Não foi possível ler o state do stack $STACK/."
    exit 1
  fi
  RECURSOS=""
fi

if [ -z "$RECURSOS" ]; then
  echo "- Stack \`$STACK/\` sem recursos no state." | tee -a "$RESUMO"
  exit 0
fi

if terraform -chdir="$DIRETORIO" apply -destroy -auto-approve -input=false "$@"; then
  echo "- Stack \`$STACK/\` destruído." | tee -a "$RESUMO"
  exit 0
fi

if [ "${REMOVER_DO_STATE_SE_FALHAR:-false}" != "true" ]; then
  echo "::error::Destroy do stack $STACK/ falhou."
  exit 1
fi

RESTANTES=$(terraform -chdir="$DIRETORIO" state list)
echo "::warning::Destroy do stack $STACK/ falhou; os recursos restantes saem do state e precisam de conferência manual."
{
  echo "- Destroy do stack \`$STACK/\` falhou. Removidos do state, conferir manualmente:"
  while IFS= read -r recurso; do
    if [ -n "$recurso" ]; then
      echo "  - \`$recurso\`"
      terraform -chdir="$DIRETORIO" state rm "$recurso" > /dev/null
    fi
  done <<< "$RESTANTES"
} >> "$RESUMO"
