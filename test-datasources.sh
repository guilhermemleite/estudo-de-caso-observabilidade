#!/bin/bash

echo "Teste de conectividade dos datasources..."

# Aguardar serviços ficarem prontos
echo "Aguardando..."
sleep 15

echo ""
echo "Teste do Prometheus..."
curl -s http://localhost:9090/api/v1/query?query=up | jq '.status' 2>/dev/null && echo "✅ Prometheus API OK" || echo "❌ Prometheus não responde"

echo ""
echo "Teste do Loki..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:3100/loki/api/v1/labels | grep -q "200" && echo "✅ Loki API OK" || echo "❌ Loki API falhou"

echo ""
echo "Teste do Tempo..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:3200/api/search | grep -q "200" && echo "✅ Tempo API OK" || echo "❌ Tempo API falhou"

echo ""
echo "Teste do Mimir..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:9009/prometheus/api/v1/query?query=up | grep -q "200" && echo "✅ Mimir API OK" || echo "❌ Mimir API falhou"

echo ""
echo "Teste do Grafana..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/login | grep -q "200" && echo "✅ Grafana Web OK" || echo "❌ Grafana Web falhou"

echo ""
echo "Aguardando Grafana inicializar completamente..."
sleep 10

echo ""
echo "Testando datasources no Grafana..."

# Testar datasources via API do Grafana
echo "- Testando datasource Prometheus..."
curl -s -u admin:admin "http://localhost:3000/api/datasources/proxy/1/api/v1/query?query=up" | jq '.status' 2>/dev/null && echo "  ✅ Datasource Prometheus OK" || echo "  ❌ Datasource Prometheus falhou"

echo "- Testando datasource Loki..."
curl -s -u admin:admin -o /dev/null -w "%{http_code}" "http://localhost:3000/api/datasources/proxy/uid/loki/loki/api/v1/labels" | grep -q "200" && echo "  ✅ Datasource Loki OK" || echo "  ❌ Datasource Loki falhou"

echo "- Testando datasource Tempo..."
curl -s -u admin:admin -o /dev/null -w "%{http_code}" "http://localhost:3000/api/datasources/proxy/uid/tempo/api/search" | grep -q "200" && echo "  ✅ Datasource Tempo OK" || echo "  ❌ Datasource Tempo falhou"

echo "- Testando datasource Mimir..."
curl -s -u admin:admin "http://localhost:3000/api/datasources/proxy/uid/mimir/api/v1/query?query=up" | jq '.status' 2>/dev/null && echo "  ✅ Datasource Mimir OK" || echo "  ❌ Datasource Mimir falhou"

echo ""
echo "Verificar no Grafana:"
echo "1. Acesse: http://localhost:3000 (admin/admin)"
echo "2. Vá em Configuration > Data Sources"
echo "3. Teste cada datasource clicando em 'Save & Test'"
echo ""
echo "Explorar dados:"
echo "1. Vá em Explore"
echo "2. Selecione cada datasource"
echo "3. Teste queries simples:"
echo "   - Prometheus/Mimir: up"
echo "   - Loki: {container_name=\"ruby-app\"}"
echo "   - Tempo: (aguarde traces serem gerados)"

echo ""
echo "Verificando logs dos serviços (últimas 5 linhas):"
echo ""
echo "=== Loki ==="
docker-compose logs --tail=5 loki 2>/dev/null || echo "Erro ao obter logs do Loki"
echo ""
echo "=== Tempo ==="
docker-compose logs --tail=5 tempo 2>/dev/null || echo "Erro ao obter logs do Tempo"
echo ""
echo "=== Grafana ==="
docker-compose logs --tail=5 grafana 2>/dev/null || echo "Erro ao obter logs do Grafana"

