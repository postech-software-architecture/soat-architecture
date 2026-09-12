# Evidencias do gate G1 — Fundacao

Capturas da API do GitHub feitas apos a configuracao da onda W1.
Coletadas em 2026-09-08 via `gh api`.

> **Nota (2026-09-08, pos-coleta):** os ambientes foram consolidados para `prod`
> unico; o Environment `homolog` foi removido dos 3 repos (era espelho de `prod`).
> Esta evidencia reflete o estado **no momento da coleta do G1** e e mantida como
> snapshot — nao foi reescrita. Estado corrente em [ESTADO.md](../../ESTADO.md).
> A referencia a `GRAFANA_*` abaixo tambem e historica; a decisao vigente usa
> `OTEL_EXPORTER_OTLP_*` com New Relic US, conforme [ADR-006](../../adr/ADR-006-opentelemetry-new-relic.md).

## Criterios do G1

| Criterio | Estado | Evidencia |
|---|---|---|
| 4 repositorios ativos e publicos | OK | `gh repo list` — os 4 com `visibility=public` |
| Branch protection nos 4 | OK | `protection-*.json` |
| Environments `homolog` / `prod` | OK (3 repos) | `environments-*.json` |
| Secret scanning + push protection | OK | `security_and_analysis` nos 4 |
| Sub-gate: `.gitignore` cobrindo `*.tfvars` | OK | `.gitignore` no 1o commit de cada repo |
| Secrets `AWS_*` / `JWT_SECRET` / `GRAFANA_*` | pendente na coleta | exigia credencial real |
| Contrato de outputs | pendente na coleta | entrega do `terraform-cluster` |
| CI minimo nos 3 repos novos | pendente na coleta | entrega do `cicd-pipelines` |
| ADR-001 / 002 / 006 | pendente na coleta | dependiam dos veredictos da W0 |
| Tag `phase3-baseline` no repo da app | pendente na coleta | antes da extracao do terraform |

## Fechamento posterior do G1

Os itens que estavam pendentes no snapshot foram concluidos: contrato com 12 outputs,
CI minima verde, ADR-001/002/006 aceitos e tag `phase3-baseline` publicada. Credenciais do
AWS Academy foram comprovadas nas execucoes da W0/W2, mas permanecem temporarias por
natureza e sao renovadas conforme o runbook; nao sao uma pendencia permanente da fundacao.
As RFCs e o contrato JWT foram formalizados antes da abertura da W3/W4. Assim, o G1 e
considerado concluido em 2026-09-12.

## Protecao aplicada

- 1 aprovacao obrigatoria por PR
- `dismiss_stale_reviews`: review e invalidada por novo push
- `required_conversation_resolution`: comentario aberto bloqueia merge
- `allow_force_pushes: false`, `allow_deletions: false`
- `enforce_admins: false` — admin pode contornar em emergencia; o G6 exige
  que o historico de fato so tenha entrado por PR

## Required status checks: ausentes de proposito

`required_status_checks: null` nos 4. Exigir um check que ainda nao existe
bloquearia **todo** merge, inclusive o PR que cria a propria CI. Os checks
sao adicionados pelo `repo-governance` na W6, depois que o `cicd-pipelines`
publicar os jobs — e o **nome** do job passa a ser contrato: renomear
depois quebra a protecao da branch.

## Environments

No snapshot, `homolog` nao tinha reviewer e `prod` exigia aprovacao de `jeanrabello`.
Depois da coleta, `homolog` foi removido e `prod` permaneceu como ambiente unico. Este e o gate que o **G6** precisa
demonstrar **bloqueando** um apply de producao.

O repo `soat-architecture` nao tem Environments: nao faz deploy.
