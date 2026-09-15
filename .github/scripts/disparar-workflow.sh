#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "uso: $0 <owner/repositorio> <arquivo-do-workflow> <branch> [-f chave=valor ...]" >&2
  exit 2
fi

REPOSITORIO="$1"
WORKFLOW="$2"
REF="$3"
shift 3

ROTULO="$REPOSITORIO · $WORKFLOW · $REF"
INICIO=$(date -u -d '-30 seconds' +%Y-%m-%dT%H:%M:%SZ)

gh workflow run "$WORKFLOW" --repo "$REPOSITORIO" --ref "$REF" "$@"
echo "Disparado: $ROTULO"

EXECUCAO=""
for _ in $(seq 1 36); do
  sleep 5
  EXECUCAO=$(gh run list --repo "$REPOSITORIO" --workflow "$WORKFLOW" --branch "$REF" \
    --event workflow_dispatch --limit 20 --json databaseId,createdAt \
    --jq "map(select(.createdAt >= \"$INICIO\")) | sort_by(.createdAt) | last | .databaseId // empty")
  if [ -n "$EXECUCAO" ]; then
    break
  fi
done

if [ -z "$EXECUCAO" ]; then
  echo "::error::A execução de $ROTULO não apareceu três minutos após o disparo."
  exit 1
fi

URL="https://github.com/$REPOSITORIO/actions/runs/$EXECUCAO"
echo "Acompanhando: $URL"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  echo "- [$ROTULO]($URL)" >> "$GITHUB_STEP_SUMMARY"
fi

if ! gh run watch "$EXECUCAO" --repo "$REPOSITORIO" --interval 30 --exit-status > /dev/null; then
  echo "::error::$ROTULO falhou: $URL"
  exit 1
fi

echo "Concluído: $ROTULO"
