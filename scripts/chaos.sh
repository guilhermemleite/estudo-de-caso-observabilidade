#!/usr/bin/env bash
# Controla a injeção de falhas do ruby-app (Game Days).
# Uso: chaos.sh status | errors <0-1> | latency <ms> | off
set -euo pipefail

URL="${CHAOS_URL:-http://localhost:4567/admin/chaos}"

post() {
  curl -s -X POST "$URL" -H 'Content-Type: application/json' -d "$1"
  echo
}

case "${1:-status}" in
  status)  curl -s "$URL"; echo ;;
  errors)  post "{\"error_rate\": ${2:?informe a taxa de erro, ex.: 0.05}}" ;;
  latency) post "{\"latency_ms\": ${2:?informe a latência em ms, ex.: 400}}" ;;
  off)     post '{"error_rate": 0, "latency_ms": 0}' ;;
  *)
    echo "Uso: $0 status | errors <0-1> | latency <ms> | off" >&2
    exit 1
    ;;
esac
