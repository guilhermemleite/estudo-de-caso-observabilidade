# Postmortem: Degradação de latência no ruby-app

| | |
|---|---|
| **Data** | 2026-11-08 |
| **Tipo** | Game Day — injeção controlada de falha (`latency_ms=400`) |
| **Duração** | 31 min (17:19:30 – 17:50:57, horário de Brasília) |
| **Severidade** | SEV-2 — degradação severa, sem indisponibilidade |
| **SLO afetado** | Latência (99% das requisições em ≤ 250 ms) |
| **Status** | Resolvido — itens de ação em aberto |
| **Formato** | Blameless |

## Resumo

Durante 31 minutos, as rotas `/products` e `/orders` responderam com latência
entre 200 e 600 ms, contra cerca de 5 ms em operação normal. Cerca de 87% das
requisições ficaram acima do limite de 250 ms do SLO, um burn rate de ~88x.
O alerta crítico disparou 25 minutos após o início da degradação. A
disponibilidade não foi afetada: nenhuma requisição retornou erro.

## Impacto

- **Usuários**: ~87% das requisições acima de 250 ms; p95 real estimado em ~580 ms.
- **Vazão**: o tráfego caiu de ~7 para ~1,9 req/s. O cliente de carga é
  sequencial e desacelerou junto com o serviço (ver "Lições aprendidas").
- **Error budget de latência**: em uma janela real de 30 dias, 31 min a ~87x
  consumiriam cerca de **6,2% do orçamento mensal** (31 × 87 / 43.200).
  No laboratório, o painel mostra -1.013%, distorção causada por haver apenas
  ~1h30 de histórico na janela de 30 dias.
- **Disponibilidade**: sem impacto (burn rate de availability = 0).

## Detecção

| Sinal | Horário | Tempo desde o início |
|---|---|---|
| Burn rate 5m (latency) começa a subir | 17:20 | ~0,5 min |
| `SLOErrorBudgetBurnSlow` → Pending | 17:28:48 | ~9 min |
| `SLOErrorBudgetBurnFast` → Pending | 17:42:48 | ~23 min |
| `SLOErrorBudgetBurnSlow` → Firing → notificação **ticket** | 17:43:48 / 17:44:20 | ~24 min |
| `SLOErrorBudgetBurnFast` → Firing → notificação **page** | 17:44:48 / 17:45:16 | ~25,8 min |

**MTTD (até o page): ~26 min.** Para um burn de ~88x, é lento demais.
A janela de 5m detectou o problema em segundos, mas o alerta crítico exige
também a janela de 1h acima de 14,4x, e essa janela estava diluída pelo
tráfego saudável anterior à falha.

## Linha do tempo (horário de Brasília)

| Horário | Evento |
|---|---|
| 17:19:30 | Início: latência de 400 ms (±50%) injetada em `/products` e `/orders` |
| 17:20 | p95 salta de ~5 ms para ~0,9 s (estimativa do histograma) |
| ~17:25 | Burn rate 5m estabiliza em ~88x |
| 17:28:48 | `SLOErrorBudgetBurnSlow` → Pending (burn 6h = 7,2x) |
| 17:42:48 | `SLOErrorBudgetBurnFast` → Pending |
| 17:43:48 | `SLOErrorBudgetBurnSlow` → Firing |
| 17:44:20 | Notificação **ticket** (aviso) |
| 17:44:48 | `SLOErrorBudgetBurnFast` → Firing (burn 1h = 18,4x) |
| 17:45:16 | Notificação **page** (crítico); aviso passa a ser inibido |
| 17:50:57 | **Mitigação**: latência injetada removida |
| ~17:55 | `SLOErrorBudgetBurnFast` resolvido (burn 5m < 14,4x) |
| 17:59:25 | Notificação de resolução do **page** (+ espera do `group_interval`) |
| ~18:15 | `SLOErrorBudgetBurnSlow` resolvido (burn 30m < 6x) |
| 18:17:18 | Notificação de resolução do **ticket** |

## Causa raiz

Latência artificial injetada via `POST /admin/chaos` (`latency_ms=400`),
no filtro `before` do Sinatra, aplicada a todas as requisições de negócio.
Em um cenário real, o padrão observado (latência uniforme em todas as rotas,
sem erros, sem aumento de CPU) apontaria para uma dependência compartilhada
lenta ou para contenção em um recurso comum.

## Investigação: como os três pilares foram usados

1. **Métricas**: burn rate de latência em ~88x e de disponibilidade em 0 →
   problema de lentidão, não de falha.
2. **Métricas (RED)**: p50/p95/p99 subiram em todas as rotas igualmente →
   causa compartilhada, não específica de uma rota.
3. **Traces**: `{resource.service.name="ruby-app" && duration > 250ms}` →
   spans únicos e longos, sem filhos → o tempo é gasto dentro do próprio
   handler, não em chamadas externas instrumentadas.
4. **Logs**: `{service="ruby-app"} | logfmt | duration_ms > 250` →
   confirma a distribuição de 200–600 ms, com `traceID` para cada caso.

## O que funcionou bem

- O SLI de latência é **exato**: 250 ms é limite de balde (`le="0.25"`),
  sem depender da interpolação do histograma.
- O roteamento por severidade funcionou: aviso → `ticket`, crítico → `page`.
- A **janela curta** cumpriu seu papel: o crítico resolveu ~4 min após a
  mitigação, embora o burn de 1h continuasse acima de 20x por mais de 30 min.
- A correlação log → trace permitiu ir de uma linha lenta ao trace em um clique.

## O que não funcionou

- **MTTD de ~26 min** para uma degradação de ~88x.
- **O aviso disparou antes do crítico**: o plantão recebeu dois alertas para
  o mesmo problema. A inibição só atua enquanto o crítico está ativo.
- **O p95 do dashboard (~0,9 s) superestimou o real (~0,58 s)**: baldes
  largos demais (0,5–1 s) na faixa onde a latência estava.
- **Spans sem filhos**: o trace mostra que o tempo foi gasto no handler,
  mas não onde.

## Onde tivemos sorte

- A falha não causou erros. Com timeouts no proxy ou no cliente, a lentidão
  teria virado indisponibilidade, afetando também o SLO de disponibilidade.
- O gerador de carga sequencial **reduziu** artificialmente o impacto
  (coordinated omission). Usuários reais continuariam chegando no mesmo ritmo.

## Itens de ação

| # | Ação | Tipo | Prioridade | Status |
|---|---|---|---|---|
| 1 | Gerador de carga de ciclo aberto (taxa de chegada constante, ex.: k6) | Detecção | P1 | Aberto |
| 2 | Revisar a calibragem dos alertas para reduzir o MTTD (janelas e `for`) | Detecção | P1 | Aberto |
| 3 | Evitar que o aviso dispare antes do crítico (ajustar `for` do aviso) | Alertas | P2 | Aberto |
| 4 | Adicionar baldes intermediários (ex.: 0,75 s) ou native histograms | Métricas | P2 | Aberto |
| 5 | Spans filhos para etapas internas do handler | Traces | P2 | Aberto |
| 6 | Garantir `http.route` em spans de requisições interrompidas cedo | Traces | P2 | Aberto |
| 7 | `runbook_url` nas anotações dos alertas | Operação | P2 | Aberto |
| 8 | Alerta de ausência de tráfego (`RubyAppNoTraffic`) | Alertas | P2 | **Concluído** |
| 9 | Política de error budget com histórico mínimo antes de decisões | Processo | P3 | Aberto |

## Lições aprendidas

1. **Coordinated omission é real**: geradores de carga de ciclo fechado
   subestimam o impacto de lentidão, porque desaceleram junto com o sistema.
2. **Percentis de histograma são estimativas**: a precisão depende da
   posição dos baldes. Limiares de SLO devem coincidir com limites de balde.
3. **Janelas longas atrasam a detecção quando há muito histórico saudável**,
   e janelas curtas fazem o alerta resolver rápido. A combinação das duas é
   o que torna o alerta confiável.
4. **Error budget precisa de histórico**: o mesmo incidente vale -1.013% em
   um ambiente recém-criado e ~6% em um serviço com 30 dias de dados.
5. **Silêncio não é saúde**: sem tráfego, os SLIs viram 0/0 e os alertas de
   SLO não avaliam (resolvido com o item 8).

## Evidências

- `docs/img/14-alerts-firing.png` — alertas em Firing no Prometheus
- `docs/img/15-latency-p95.png` — p95 estimado durante o incidente
- `docs/img/16-alertmanager-inhibited.png` — inibição do aviso pelo crítico
- `docs/img/17-dashboard-red-slo.png` — dashboard RED + SLO com o incidente
- `docs/postmortems/2026-11-08-notas-incidente.md` — notas brutas (incidentes 1 e 2)
