# Notas brutas — incidente simulado 2026-11-08

## Linha do tempo (horário de Brasília)
| Horário   | Evento |
|-----------|--------|
| 16:46     | Teste do chaos com 30% de erros (~segundos), com tráfego ativo |
| 16:52     | Recording rules de SLO carregadas |
| 16:55     | Script de tráfego termina (lacuna sem tráfego até 16:59) |
| 16:59     | Início da falha: 5% de erros em /products e /orders (chaos error_rate=0.05) |
| 16:59:40  | slo:burn_rate:ratio_rate5m (availability) começa a subir |
| ~17:01:30 | Burn rate 5m estabiliza entre 8,6x e 10x |
| 17:07     | Burn rate 30m em 4,1x; error_budget_remaining (30d) em -3,38 |
| 17:09:03  | Falha desligada (error_rate=0) |
| ~17:14    | Burn rate 5m volta a zero (esperado) |

## Observações
- Erros rápidos (duration_ms ~0.07): falha antes da lógica da rota.
- Spans de erro sem http.route (nomeados só "GET"/"POST"): o halt no filtro
  before acontece antes do roteamento do Sinatra.
- Error budget de 30d distorcido: só ~20 min de histórico com o label status.
  O mesmo incidente com 30 dias de histórico consumiria ~0,19% do orçamento.
- Latência não foi afetada (burn rate de latency = 0 o tempo todo).
- Busca do Tempo não ordena por tempo: usar janelas curtas para achar traces recentes.

## Evidências
- docs/img/12-slo-burn-rate.png
- docs/img/13-falha-logs-traces.png
