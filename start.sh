#!/bin/bash

echo "Iniciando..."

# Limpeza de containers antigos, caso existam.
echo "Executando limpeza de containers antigos..."
docker-compose down 2>/dev/null || true
docker system prune -f 2>/dev/null || true

# Construção de imagens.
echo "Construindo imagens..."
docker-compose build --no-cache

# Verificação da construção de imagens.
if [ $? -ne 0 ]; then
    echo "❌ Erro na construção das imagens!"
    exit 1
fi

# Iniciar serviços
echo "Iniciando serviços..."
docker-compose up -d

echo "Aguardando serviços..."
sleep 60

# Verificar se os serviços estão executando
echo "Verificando status dos serviços..."
docker-compose ps

echo ""
echo "✅ Stack iniciada com sucesso!"
echo ""
echo "Aplicação: http://localhost"
echo "Grafana: http://localhost:3000 (admin/admin)"
echo "Prometheus: http://localhost:9090"
echo "Loki: http://localhost:3100"
echo "Tempo: http://localhost:3200"
echo "Mimir: http://localhost:9009"
echo ""
echo "Gerar métricas de teste: ./test-metrics.sh"
echo "Testar datasources: ./test-datasources.sh"
echo "Visualizar logs: docker-compose logs -f [serviço]"
echo "Parar: docker-compose down"
echo ""

# Teste de conectividade simples
echo "Testando conectividade..."
sleep 10

echo "- Testando aplicação Ruby..."
curl -s http://localhost/api/health > /dev/null && echo "  ✅ Ruby OK" || echo "  ❌ Ruby falhou"

echo "- Testando métricas..."
curl -s http://localhost/metrics > /dev/null && echo "  ✅ Métricas OK" || echo "  ❌ Métricas falharam"

echo "- Testando Prometheus..."
curl -s http://localhost:9090/-/healthy > /dev/null && echo "  ✅ Prometheus OK" || echo "  ❌ Prometheus falhou"

echo "- Testando Loki..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:3100/loki/api/v1/labels | grep -q "200" && echo "  ✅ Loki OK" || echo "  ❌ Loki falhou"

echo "- Testando Tempo..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:3200/api/search | grep -q "200" && echo "  ✅ Tempo OK" || echo "  ❌ Tempo falhou"

echo "- Testando Mimir..."
curl -s http://localhost:9009/ready > /dev/null && echo "  ✅ Mimir OK" || echo "  ❌ Mimir falhou"

echo "- Testando Grafana..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/login | grep -q "200" && echo "  ✅ Grafana OK" || echo "  ❌ Grafana falhou"

echo ""
echo "Execute './test-metrics.sh' para gerar dados de teste."
echo "Execute './test-datasources.sh' para testar conectividade dos datasources."

