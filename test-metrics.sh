#!/bin/bash

echo "Teste e geração de métricas..."

# Aguardar serviços ficarem prontos
echo "Aguardando serviços..."
sleep 10

# Gerar algumas métricas fazendo requisições
echo "Gerando métricas..."

for i in {1..20}; do
    echo "Requisição $i/20"
    
    # Health check
    curl -s http://localhost/api/health > /dev/null || echo "❌ Health check falhou"
    
    # Produtos
    curl -s http://localhost/api/products > /dev/null || echo "❌ Products falhou"
    
    # Criar pedido ocasionalmente
    if [ $((i % 5)) -eq 0 ]; then
        curl -s -X POST -H "Content-Type: application/json" \
             -d '{"product_id": 1}' \
             http://localhost/api/orders > /dev/null || echo "❌ Order falhou"
    fi
    
    sleep 1
done

echo ""
echo "✅ Métricas geradas!"
echo ""
echo "Verificando métricas:"
echo "1. Métricas da aplicação: http://localhost/metrics"
echo "2. Prometheus targets: http://localhost:9090/targets"
echo "3. Grafana explore: http://localhost:3000/explore"
echo ""

# Mostrar algumas métricas geradas.
echo "Métricas atuais:"
curl -s http://localhost/metrics | grep -E "(http_requests_total|products_viewed_total|orders_created_total)"

