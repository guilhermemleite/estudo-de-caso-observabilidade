#!/usr/bin/env bash
# Verifica se todos os componentes da stack estão respondendo.
# Repete cada verificação antes de declarar falha: logo após subir, Mimir,
# Loki e Tempo levam ~30s para ficar prontos, e o /ready pode oscilar.
# Sai com código 1 se algum componente falhar (útil em CI).
set -u

RETRIES="${RETRIES:-10}"   # tentativas por componente
INTERVAL="${INTERVAL:-3}"  # segundos entre tentativas
fail=0

check() {
  local name="$1" url="$2" code attempt
  for attempt in $(seq 1 "$RETRIES"); do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url")
    if [ "$code" = "200" ]; then
      printf '  ✅ %-13s %s\n' "$name" "$url"
      return 0
    fi
    [ "$attempt" -lt "$RETRIES" ] && sleep "$INTERVAL"
  done
  printf '  ❌ %-13s %s (HTTP %s após %s tentativas)\n' "$name" "$url" "${code:-sem resposta}" "$RETRIES"
  fail=1
}

echo "Verificando a stack (até ${RETRIES} tentativas por componente)..."
check "nginx/app"    "http://localhost/api/products"
check "ruby-app"     "http://localhost:4567/health"
check "prometheus"   "http://localhost:9090/-/ready"
check "alertmanager" "http://localhost:9093/-/ready"
check "mimir"        "http://localhost:9009/ready"
check "loki"         "http://localhost:3100/ready"
check "tempo"        "http://localhost:3200/ready"
check "alloy"        "http://localhost:12345/-/ready"
check "grafana"      "http://localhost:3000/api/health"

if [ "$fail" -eq 0 ]; then
  echo "Tudo pronto."
else
  echo "Algum componente não respondeu. Veja os logs com: make logs s=<serviço>"
fi
exit "$fail"
