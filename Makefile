# Atalhos do projeto. Rode "make" ou "make help" para ver todos.
.RECIPEPREFIX = >
.DEFAULT_GOAL := help
.PHONY: help up down ps logs health traffic traffic-stop \
        chaos-status chaos-errors chaos-latency chaos-off clean

DURATION   ?= 600    # duração do tráfego, em segundos
ERROR_RATE ?= 0.05   # taxa de erro do chaos (0 a 1)
LATENCY_MS ?= 400    # latência injetada, em ms
s          ?=        # serviço para "make logs s=<nome>"

help: ## Lista os comandos disponíveis
> @grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

up: ## Sobe a stack (build incluso)
> docker compose up -d --build
> @echo "Aguarde ~30s e rode: make health"

down: ## Para a stack (mantém os dados)
> docker compose down

ps: ## Status dos containers
> @docker compose ps --format "table {{.Name}}\t{{.Image}}\t{{.Status}}"

logs: ## Logs ao vivo (todos, ou um serviço: make logs s=ruby-app)
> docker compose logs -f $(s)

health: ## Verifica se todos os componentes respondem
> @./scripts/healthcheck.sh

traffic: ## Gera tráfego em segundo plano (DURATION=600)
> @pkill -f scripts/traffic.sh || true
> @DURATION=$(DURATION) nohup ./scripts/traffic.sh > /tmp/traffic.log 2>&1 &
> @echo "Tráfego iniciado por $(DURATION)s (log em /tmp/traffic.log)"

traffic-stop: ## Para o gerador de tráfego
> @pkill -f scripts/traffic.sh && echo "Tráfego parado" || echo "Nenhum tráfego em execução"

chaos-status: ## Mostra a configuração atual do chaos
> @./scripts/chaos.sh status

chaos-errors: ## Injeta erros 5xx (ERROR_RATE=0.05)
> @./scripts/chaos.sh errors $(ERROR_RATE)

chaos-latency: ## Injeta latência (LATENCY_MS=400)
> @./scripts/chaos.sh latency $(LATENCY_MS)

chaos-off: ## Desliga toda injeção de falha
> @./scripts/chaos.sh off

clean: ## Remove containers E volumes (apaga métricas, logs e traces!)
> @echo "Isto apaga todos os dados da stack. Ctrl+C para cancelar (5s)..."
> @sleep 5
> docker compose down -v
