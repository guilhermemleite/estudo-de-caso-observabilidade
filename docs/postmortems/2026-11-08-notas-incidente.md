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

---

# Incidente 2 — degradação de latência

## Linha do tempo (horário de Brasília)
| Horário   | Evento |
|-----------|--------|
| ~17:19:30 | Início: latência injetada de 400 ms (±50%) em /products e /orders |
| 17:20     | slo:burn_rate:ratio_rate5m (latency) começa a subir |
| ~17:25    | Burn rate 5m estabiliza em ~88x; p95 estimado em ~0,9 s |
| 17:28:48  | SLOErrorBudgetBurnSlow -> Pending (burn 6h = 7,2x) |
| 17:42:48  | SLOErrorBudgetBurnFast -> Pending |
| 17:43:48  | SLOErrorBudgetBurnSlow -> Firing -> notificação no canal "ticket" |
| 17:44:48  | SLOErrorBudgetBurnFast -> Firing (burn 1h = 18,4x) -> canal "page"; aviso passa a ser inibido |
| 17:50:57  | Falha desligada (latency_ms=0) |

## Observações
- MTTD de ~24 min até o primeiro alerta, para um burn de ~87x. Causas:
  1. Janelas longas (1h/6h) diluídas por tráfego saudável anterior à falha.
  2. Gerador de carga de ciclo fechado: a latência reduziu o tráfego de ~7 para ~1,9 req/s
     (coordinated omission), diminuindo o peso das requisições lentas.
- O aviso (ticket) disparou 1 min antes do crítico (page): o plantão recebeu dois
  alertas para o mesmo problema. A inibição só suprime enquanto o crítico está ativo.
- p95 estimado em ~0,9 s, mas o real era ~0,58 s: histogram_quantile interpola
  linearmente dentro do balde (0,5–1 s]. O SLI de latência é exato porque
  250 ms é limite de balde (le="0.25").
- Disponibilidade não foi afetada (burn de availability = 0).
