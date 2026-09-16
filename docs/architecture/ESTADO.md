# Estado da entrega — Fase 3

Levantamento baseado no codigo, nos workflows executados e no ambiente AWS Academy
efetivamente usado pelo grupo. Quando o planejamento original diverge da execucao, o
estado real registrado aqui prevalece.

**Atualizado em:** 2026-09-15

**Onda atual:** W5 — observabilidade operacional

**Situacao:** W0–W2 concluidas; W3 encerrada, incluindo a coleta quantitativa de
`EXPLAIN`; W4 concluida e G4 aprovado. A W5 esta implantada com telemetria real de
cluster, aplicacao e Lambda na conta New Relic 8494284: **28 dos 31 widgets** dos
seis dashboards tem dados, medidos apos exercitar os endpoints. O ciclo do alerta
foi exercitado de ponta a ponta: incidente aberto as 19:13:19Z por cinco janelas
consecutivas acima do limiar e fechado as 19:20:19Z depois que a carga parou. A
varredura de dados sensiveis em `prod` nao encontrou CPF, documento, JWT nem
senha. Para fechar o G5 faltam as capturas sanitizadas e o trace unico entre
Lambda e aplicacao, indisponivel por limitacao da camada. Nenhuma divida de
evidencia anterior a W5 permanece aberta.

**Ambiente:** `prod` unico; credenciais temporarias do AWS Academy sao renovadas por janela.

---

## Resumo por onda

| Onda | Estado | Evidencia ou proximo gate |
|---|---|---|
| **W0 — spikes de risco** | **concluida** | LabRole, VPC Link/NLB, OTLP/New Relic e backend remoto aprovados |
| **W1 — fundacao** | **concluida** | 4 repositorios, protecoes, CI minima, contrato de outputs, RFCs e ADRs publicados |
| **W2 — cloud + higiene** | **concluida** | EKS/Kustomize validados; logs JSON/OTLP e correlacao integrados; CI verde; destroy comprovado |
| **W3 — dados + contrato** | **concluida** | EKS, RDS, Flyway, duas replicas e readiness externo validados; `EXPLAIN` medido em [evidence/w3/explain](evidence/w3/explain/README.md) |
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

A infraestrutura da W5 esta no ar, a telemetria de cluster, aplicacao e Lambda
chega ao New Relic e o [runbook](runbooks/w5-execucao.md) ja foi executado contra
o ambiente. O que falta para fechar o G5 esta detalhado em
[evidence/w5/README.md](evidence/w5/README.md); em resumo:

1. registrar as capturas de tela sanitizadas dos seis dashboards e do ciclo do
   incidente, unico item que exige acesso visual a conta;
2. confirmar no destino configurado que a notificacao do incidente chegou;
3. tratar o state remoto dos assets antes do proximo apply, porque cada execucao
   sem state recria e duplica recursos — ja aconteceu com os seis dashboards e
   com tres politicas de alerta, ambos limpos pela API.

O painel da Lambda esta completo. Traces da funcao permanecem indisponiveis por
limitacao da camada, o que afeta apenas o criterio de correlacao — detalhado em
[evidence/w5](evidence/w5/README.md).

A divida de `EXPLAIN (ANALYZE, BUFFERS)` da W3 foi encerrada em 2026-09-14; ver
[evidence/w3/explain](evidence/w3/explain/README.md). Dela sai uma acao para o backlog:
criar o indice parcial `ordens_servico (data_criacao, status) WHERE data_remocao IS NULL`,
que a medicao promoveu de candidato a recomendacao.

Antes de encerrar a janela AWS, destruir na ordem inversa: serverless, depois
database (`DESTRUIR DATABASE ANTES DO CLUSTER`), depois EKS (`DESTRUIR-PROD`). O
destroy do EKS ja falhou uma vez por ENIs de Lambda ainda anexadas, e o gate do
repositorio bloqueia enquanto o `db_client_sg_id` estiver em uso.
