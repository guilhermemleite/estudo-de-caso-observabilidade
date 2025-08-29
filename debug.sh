#!/bin/bash

echo "Script de Debug"
echo ""

# Verificar se Docker está funcionando
echo "1. Verificando Docker..."
docker --version
docker-compose --version
echo ""

# Tentar construir apenas a aplicação Ruby
echo "2. Testando construção da aplicação Ruby..."
cd ruby-app
docker build -t test-ruby-app .

if [ $? -eq 0 ]; then
    echo "✅ Construção da aplicação Ruby OK"
    
    # Teste de execução
    echo "3. Testando execução da aplicação Ruby..."
    docker run -d --name test-ruby -p 4567:4567 test-ruby-app
    
    sleep 5
    
    echo "4. Testando endpoint de health..."
    curl -s http://localhost:4567/health || echo "❌ Falha no health check"
    
    echo "5. Testando endpoint de métricas..."
    curl -s http://localhost:4567/metrics || echo "❌ Falha nas métricas"
    
    # Limpar
    docker stop test-ruby 2>/dev/null
    docker rm test-ruby 2>/dev/null
    docker rmi test-ruby-app 2>/dev/null
    
else
    echo "❌ Falha na construção da aplicação Ruby"
    echo "Verifique os logs acima para mais detalhes"
fi

echo ""
echo "Debug concluído!"

