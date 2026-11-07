#!/usr/bin/env bash
# Gera tráfego contínuo: vários GET /api/products e um POST /api/orders por ciclo
BASE="${BASE:-http://localhost}"
DURATION="${DURATION:-600}"   # segundos (padrão: 10 min)
end=$((SECONDS + DURATION))

echo "Gerando tráfego em $BASE por ${DURATION}s..."
while [ $SECONDS -lt $end ]; do
  for i in $(seq 1 $((RANDOM % 5 + 1))); do
    curl -s -o /dev/null "$BASE/api/products"
  done
  curl -s -o /dev/null -X POST "$BASE/api/orders" \
       -H 'Content-Type: application/json' \
       -d "{\"product_id\": $((RANDOM % 2 + 1))}"
  sleep 0.$((RANDOM % 9 + 1))
done
echo "Tráfego finalizado."
