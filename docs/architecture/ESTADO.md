# Estado da entrega — Fase 3

Levantamento baseado no codigo, nos workflows executados e no ambiente AWS Academy
efetivamente usado pelo grupo. Quando o planejamento original diverge da execucao, o
estado real registrado aqui prevalece.

**Atualizado em:** 2026-09-15

**Onda atual:** W5 — observabilidade operacional

**Situacao:** W0–W2 concluidas; gate operacional da W3 executado; W4 concluida e G4
aprovado. A W5 esta implantada e emitindo telemetria real: cluster, aplicacao,
dashboards e alerta validados na conta New Relic 8494284. Faltam para o G5 as
metricas de negocio `workshop.*`, que exigem exercitar o fluxo de ordem de servico,
e os sinais da Lambda. A W3 mantem a coleta quantitativa de `EXPLAIN` como divida.

**Ambiente:** `prod` unico; credenciais temporarias do AWS Academy sao renovadas por janela.

---

## Resumo por onda

| Onda | Estado | Evidencia ou proximo gate |
|---|---|---|
| **W0 — spikes de risco** | **concluida** | LabRole, VPC Link/NLB, OTLP/New Relic e backend remoto aprovados |
| **W1 — fundacao** | **concluida** | 4 repositorios, protecoes, CI minima, contrato de outputs, RFCs e ADRs publicados |
| **W2 — cloud + higiene** | **concluida** | EKS/Kustomize validados; logs JSON/OTLP e correlacao integrados; CI verde; destroy comprovado |
| **W3 — dados + contrato** | **gate operacional concluido** | EKS, RDS, Flyway, duas replicas e readiness externo validados; `EXPLAIN` quantitativo pendente |
| **W4-A / W4-B** | **concluida** | Lambda/CPF, JWT, Gateway, VPC Link e NLB interno validados no G4; ver [evidence/w4](evidence/w4/README.md) |
| W5 — observabilidade | **implantada; G5 parcial** | infraestrutura provisionada e telemetria fluindo; ver [evidence/w5](evidence/w5/README.md) e o [runbook de execucao](runbooks/w5-execucao.md) |
| W6 — governanca | nao iniciada | depende do G5 |
| W7 — entrega | nao iniciada | gravar antes de destruir a infraestrutura final |

## W0 — quatro riscos encerrados

| Spike | Veredicto | Evidencia |
|---|---|---|
| LabRole assumivel por Lambda | aprovado | Lambda temporaria respondeu 200 e foi removida |
| VPC Link + NLB interno | aprovado | VPC Link `AVAILABLE` e proxy pelo API Gateway respondeu 200 |
| Ingestao OTLP / New Relic US | aprovado | endpoint respondeu 200 e o span foi localizado pelo `trace.id` |
| Tempo de EKS + backend S3 | aprovado | apply/destroy medidos; S3 e DynamoDB preservados |

Os veredictos estao detalhados em [evidence/w0-w2/README.md](evidence/w0-w2/README.md)
e fundamentam os ADR-001, ADR-002, ADR-005 e ADR-006.

## W1 — fundacao concluida

| Item | Estado |
|---|---|
| 4 repositorios publicos e ativos | concluido |
| Branch protection e secret scanning | concluido e comprovado bloqueando merge sem aprovacao |
| Environment `prod` nos repos de deploy | concluido |
| Contrato de outputs da infraestrutura | concluido, com 12 outputs |
| CI minima nos repos novos | concluido |
| RFC-001 a RFC-004 | aceitas e versionadas |
| ADR-001 a ADR-006 aplicaveis ate esta onda | publicados; ADR-003/004 congelam a W4 |

Credenciais do AWS Academy nao sao secrets permanentes da fundacao. Elas expiram em
aproximadamente quatro horas e sao renovadas apenas no inicio de cada janela controlada,
conforme [runbooks/secrets.md](runbooks/secrets.md). Esse comportamento operacional nao
mantem a W1 aberta.

## W2 — cloud e higiene concluidas

O cluster foi criado no AWS Academy, os nodes ficaram `Ready`, e `metrics-server`, AWS
Load Balancer Controller e workloads Kustomize foram validados. O fluxo privado
API Gateway -> VPC Link -> NLB -> EKS respondeu HTTP 200.

Na aplicacao, o
[PR #65](https://github.com/postech-software-architecture/workshop-service-fase1/pull/65)
adicionou logs JSON em `prod`, exportador de metricas OTLP desligado por padrao,
`X-Correlation-ID`, extracao de `traceparent` e limpeza do MDC. A
[CI 34718784454](https://github.com/postech-software-architecture/workshop-service-fase1/actions/runs/34718784454)
passou com testes e cobertura.

Ao final, o
[destroy 34716906674](https://github.com/postech-software-architecture/workshop-infra-kubernetes/actions/runs/34716906674)
removeu 24 recursos e preservou o objeto de state no S3 e a tabela de lock no DynamoDB.

## Cenario de dados corrigido para a W3

O planejamento original pressupunha uma instancia RDS semeada no mesmo ambiente e, por
isso, tornava obrigatorios uma auditoria read-only de orfaos e um `terraform import`.
O ambiente alvo atual usa **outra conta AWS Academy e comeca sem instancia RDS**.

Consequencias:

- import de RDS, subnet group e security group: **nao aplicavel** somente quando a consulta
  individual confirmar a ausencia dos tres objetos gerenciados;
- auditoria de dados persistidos: **nao aplicavel**, pois nao ha base legada nessa conta;
- integridade do seed: continua obrigatoria e sera provada na W3 por Testcontainers,
  executando todas as migrations e as quatro FKs sobre uma base vazia;
- antes do primeiro `apply`, consultas read-only devem confirmar separadamente que nao
  existem a instancia `workshop-db`, o DB subnet group `workshop-db-subnets` e o security
  group `workshop-db-sg` (por nome/tag e VPC). Uma lista vazia apenas de instancias RDS nao
  libera o apply. Se qualquer um desses objetos existir, o fluxo muda para reconciliacao e
  import do objeto correspondente; nenhum apply e permitido antes disso.

## Decisoes e riscos ainda abertos

| Item | Tratamento |
|---|---|
| Segredo JWT historico esta comprometido | default ja removido; gerar valor novo na janela da W4 e nunca reutilizar o valor do historico |
| Duas OpenAPI divergentes | resolvido na W3: uma unica `openapi.yaml` na raiz, 63 operacoes conferidas contra os controllers |
| Quatro FKs ausentes | resolvido na W3: migration com as quatro FKs `RESTRICT` e dois indices, validada por Testcontainers sobre base vazia |
| Nodes sem identidade de cliente do banco | resolvido na W3: `db_client_sg_id` anexado aos nodes e autorizado como origem exclusiva do RDS |
| Credenciais temporarias | renovar no inicio da janela; nao iniciar apply perto da expiracao |
| Required status checks definitivos | W6, depois que os nomes dos jobs estabilizarem |

## Proximo passo recomendado

A infraestrutura da W5 esta no ar e a telemetria de cluster e aplicacao chega ao New
Relic. O que falta para fechar o G5 esta detalhado em
[evidence/w5/README.md](evidence/w5/README.md); em resumo:

1. executar o [runbook da W5](runbooks/w5-execucao.md) para gerar as metricas
   `workshop.*` e disparar o alerta controlado;
2. confirmar os sinais da Lambda apos a reciclagem das ENIs;
3. registrar as capturas e consultas NRQL sanitizadas.

Em paralelo, coletar o `EXPLAIN (ANALYZE, BUFFERS)` pendente da W3.

Antes de encerrar a janela AWS, destruir na ordem inversa: serverless, depois
database (`DESTRUIR DATABASE ANTES DO CLUSTER`), depois EKS (`DESTRUIR-PROD`). O
destroy do EKS ja falhou uma vez por ENIs de Lambda ainda anexadas, e o gate do
repositorio bloqueia enquanto o `db_client_sg_id` estiver em uso.
