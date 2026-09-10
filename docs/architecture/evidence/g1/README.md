# Evidencias do gate G1 — Fundacao

Capturas da API do GitHub feitas apos a configuracao da onda W1.
Coletadas em 2026-09-08 via `gh api`.

> **Nota (2026-09-08, pos-coleta):** os ambientes foram consolidados para `prod`
> unico; o Environment `homolog` foi removido dos 3 repos (era espelho de `prod`).
> Esta evidencia reflete o estado **no momento da coleta do G1** e e mantida como
> snapshot — nao foi reescrita. Estado corrente em [ESTADO.md](../../ESTADO.md).

## Criterios do G1

| Criterio | Estado | Evidencia |
|---|---|---|
| 4 repositorios ativos e publicos | OK | `gh repo list` — os 4 com `visibility=public` |
| Branch protection nos 4 | OK | `protection-*.json` |
| Environments `homolog` / `prod` | OK (3 repos) | `environments-*.json` |
| Secret scanning + push protection | OK | `security_and_analysis` nos 4 |
| Sub-gate: `.gitignore` cobrindo `*.tfvars` | OK | `.gitignore` no 1o commit de cada repo |
| Secrets `AWS_*` / `JWT_SECRET` / `GRAFANA_*` | **PENDENTE** | exige credencial real |
| Contrato de outputs | **PENDENTE** | entrega do `terraform-cluster` |
| CI minimo nos 3 repos novos | **PENDENTE** | entrega do `cicd-pipelines` |
| ADR-001 / 002 / 006 | **PENDENTE** | dependem dos veredictos da W0 |
| Tag `phase3-baseline` no repo da app | **PENDENTE** | antes da extracao do terraform |

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

`homolog`: sem reviewer, deploy automatico a partir de `develop`.
`prod`: exige aprovacao de `jeanrabello`. Este e o gate que o **G6** precisa
demonstrar **bloqueando** um apply de producao.

O repo `soat-architecture` nao tem Environments: nao faz deploy.
