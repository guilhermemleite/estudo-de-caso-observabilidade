#!/bin/bash

echo "Script de Diagnóstico e Correção"
echo ""

echo "1. Verificando status dos containers..."
docker-compose ps

echo ""
echo "2. Verificando logs dos serviços com problemas..."

echo ""
echo "LOGS LOKI (últimas 10 linhas)"
docker-compose logs --tail=10 loki

echo ""
echo "LOGS TEMPO (últimas 10 linhas)"
docker-compose logs --tail=10 tempo

echo ""
echo "LOGS GRAFANA (últimas 10 linhas)"
docker-compose logs --tail=10 grafana

echo ""
echo "3. Testando conectividade de rede..."

echo "- Testando se containers estão na mesma rede..."
docker network ls | grep observabilidade

echo ""
echo "- Testando resolução DNS entre containers..."
docker-compose exec ruby-app ping -c 2 loki 2>/dev/null || echo "❌ Ruby não consegue alcançar Loki"
docker-compose exec ruby-app ping -c 2 tempo 2>/dev/null || echo "❌ Ruby não consegue alcançar Tempo"
docker-compose exec ruby-app ping -c 2 grafana 2>/dev/null || echo "❌ Ruby não consegue alcançar Grafana"

echo ""
echo "4. Verificando portas dos serviços..."
echo "- Loki (3100): $(curl -s -o /dev/null -w "%{http_code}" http://localhost:3100/metrics)"
echo "- Tempo (3200): $(curl -s -o /dev/null -w "%{http_code}" http://localhost:3200/metrics)"
echo "- Grafana (3000): $(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/login)"

echo ""
echo "5. Verificando configurações..."
echo "- Verificando se arquivos de configuração existem..."
ls -la monitoring/

echo ""
echo "6. Reiniciando serviços com problemas..."
echo "Reiniciando Loki..."
docker-compose restart loki
sleep 10

echo "Reiniciando Tempo..."
docker-compose restart tempo
sleep 10

echo "Reiniciando Grafana..."
docker-compose restart grafana
sleep 15

echo ""
echo "7. Testando novamente após reinicialização..."
echo "- Loki: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:3100/loki/api/v1/labels)"
echo "- Tempo: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:3200/api/search)"
echo "- Grafana: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/login)"

echo ""
echo "✅ Diagnóstico concluído!"
echo ""
echo "Se os problemas persistirem:"
echo "1. Execute: docker-compose down"
echo "2. Execute: docker system prune -f"
echo "3. Execute: ./start.sh"

