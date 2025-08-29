# Solução do Estudo de Caso de Observabilidade

Esta é uma solução mínima mas funcional para instrumentar uma aplicação legada Ruby com Nginx, usando uma stack completa de observabilidade com Grafana, Prometheus, Mimir, Loki e Tempo.

## Como Executar:

1. **Clone o repositório**
2. **Execute o script de inicialização:**
   ```bash
   ./start.sh
   ```
3. **Acesse os serviços:**
   - **Aplicação**: `http://localhost` (página simples com links)
   - **API direta**: `http://localhost/api/health`
   - **Métricas**: `http://localhost/metrics`
   - **Grafana**: `http://localhost:3000` (usuário: `admin`, senha: `admin`)
   - **Prometheus**: `http://localhost:9090`

## Arquitetura

- **Backend**: Aplicação Ruby legada com instrumentação manual
- **Frontend**: Nginx como proxy reverso (página HTML mínima)
- **Monitoramento**: Stack completa com Grafana, Prometheus, Mimir, Loki e Tempo

## Passo a Passo da Implementação

1. **Aplicação Ruby**: Foi criada uma aplicação Sinatra simples com um endpoint `/metrics` que expõe métricas no formato Prometheus
2. **Nginx**: Foi configurado o Nginx para servir uma página HTML simples e redirecionar as requisições para a aplicação Ruby
3. **Stack de Observabilidade**: Configurado o Prometheus, Mimir, Loki, Tempo e Grafana para coletar e visualizar os dados da aplicação
4. **Docker Compose**: Criado um `docker-compose.yml` para orquestrar todos os serviços
5. **Script de Inicialização**: Criado um script `start.sh` para facilitar a execução da stack


## ✅ Conclusão

Esta solução atende aos requisitos proposto do Estudo de Caso de forma simples e funcional, demonstrando como instrumentar uma aplicação legada sem suporte a OpenTelemetry ou Prometheus Exporter, mantendo a arquitetura Nginx + Ruby + Stack de Observabilidade.


## Verificar a coleta de dados

### Passo 1: Gerar Métricas
Após iniciar, execute:
```bash
./test-metrics.sh
```

### Passo 2: Verificar no Prometheus
1. Acesse: `http://localhost:9090`
2. Vá em **Status > Targets**
3. Verifique se os targets estão **UP**
4. Vá em **Graph** e digite: `http_requests_total`

### Passo 3: Verificar no Grafana
1. Acesse: `http://localhost:3000` (admin/admin)
2. Vá em **Explore**
3. Selecione **Prometheus** como datasource
4. Digite: `http_requests_total` e execute

### Passo 4: Troubleshooting de Coleta

Se as métricas não aparecerem:

```bash
# Verificar se a aplicação está expondo métricas
curl http://localhost/metrics

# Verificar targets no Prometheus
curl http://localhost:9090/api/v1/targets

# Ver logs do Prometheus
docker-compose logs prometheus

# Ver logs da aplicação Ruby
docker-compose logs ruby-app
```

### Métricas Disponíveis

A aplicação expõe as seguintes métricas:
- `http_requests_total` - Total de requisições HTTP
- `products_viewed_total` - Total de produtos visualizados  
- `orders_created_total` - Total de pedidos criados

