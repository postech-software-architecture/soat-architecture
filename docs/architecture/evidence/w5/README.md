# Evidencia da W5 — observabilidade operacional

Execucao de 2026-09-15 na conta AWS Academy `724661471900` e na conta New Relic
`8494284`. Os numeros abaixo foram lidos por consulta NRQL e pela API da AWS
durante a janela, nao estimados.

## Ambiente provisionado

| Componente | Estado verificado | Run |
|---|---|---|
| EKS `workshop-eks` | `ACTIVE`, versao 1.35, 2 nodes `Ready` | [34922210504](https://github.com/postech-software-architecture/workshop-infra-kubernetes/actions/runs/34922210504) |
| RDS `workshop-db` | `available`, `PubliclyAccessible=false`, `StorageEncrypted=true` | [34924107561](https://github.com/postech-software-architecture/workshop-infra-database/actions/runs/34924107561) |
| Aplicacao no EKS | 2 pods `1/1`, `/actuator/health` `UP` | [34925342639](https://github.com/postech-software-architecture/workshop-service-fase1/actions/runs/34925342639) |
| Lambda `workshop-auth-cpf` | `Active`, HTTP 422 consistente no smoke | [34928618715](https://github.com/postech-software-architecture/workshop-auth-serverless/actions/runs/34928618715) |
| Assets New Relic | 6 dashboards, politica e canal criados | [34921174998](https://github.com/postech-software-architecture/soat-architecture/actions/runs/34921174998) |

Stage do API Gateway: `prod`. O caminho publico inclui o stage —
`https://<api-id>.execute-api.us-east-1.amazonaws.com/prod/api/auth/cpf`. Omitir
`/prod` devolve 404, o que ja custou uma investigacao.

## Sinais chegando

Medido em janela de 30 minutos:

| Sinal | Volume |
|---|---|
| Metricas do cluster (`k8s.cluster.name = 'workshop-eks'`) | 34.671 |
| Spans de `workshop-service` | 1.645 |
| Spans JDBC (`db.system IS NOT NULL`) | presentes, incluindo `SELECT "public"."flyway_schema_history"` |
| Logs por namespace | `workshop` e `kube-system` |
| Nodes reportando | 2, por `k8s.node.name` |

Atributos de recurso conferidos nos spans: `deployment.environment = 'prod'` e
`service.version = 'sha-1b3c19651fa7fabeedc99827dc42844a7df0ff4d'`.

## Criterios do G5

| # | Criterio | Estado |
|---|---|---|
| 1 | Seis dashboards com dados reais | **parcial** — ver tabela abaixo |
| 2 | Trace HTTP com span JDBC | **atendido** |
| 3 | Mesmo `correlationId` na Lambda e na aplicacao | pendente |
| 4 | Incidente aberto por falha controlada | pendente |
| 5 | Notificacao entregue | pendente |
| 6 | Incidente recuperado | pendente |
| 7 | Busca sem CPF, JWT, senha ou segredo | **parcial** — ver higiene |

### Dashboards

Os 31 widgets foram executados contra a conta: nenhum tem erro de sintaxe.

| Dashboard | Widgets com dados |
|---|---|
| W5 - Service Overview | 6/6 |
| W5 - EKS Infrastructure | 7/7 |
| W5 - Dependencies and Correlation | 5/6 |
| W5 - Auth Serverless | 1/4 |
| W5 - Ordem de Servico Lifecycle | 1/4 |
| W5 - Ordem de Servico Reliability | 1/4 |

Os paineis vazios dependem de dados ainda nao gerados, nao de consulta incorreta:
`workshop.*` exige exercitar o fluxo de ordem de servico, e os widgets da Lambda
dependem dos sinais dela.

### Alerta

Politica `W5 - Workshop Operational Observability`, condicao
`W5 - three processing failures in five minutes`, habilitada:

```
FROM Metric SELECT sum(workshop.ordem_servico.processing.error.count)
WHERE environment = 'prod'
```

`ABOVE_OR_EQUALS 3`, `thresholdDuration 300`, `thresholdOccurrences ALL`. Destino
de notificacao do tipo `WEBHOOK` criado e ativo.

O caminho que alimenta a metrica foi validado em ambiente local antes do deploy:
tres transicoes invalidas seguidas elevaram o contador a exatamente 3, com as tags
`stage=execucao`, `operation=iniciar`, `outcome=error`. Falta reproduzir em `prod`
para abrir o incidente.

### Higiene

Na validacao local com o mesmo seed: zero ocorrencias do documento do cliente, do
prefixo `eyJ` de JWT e da senha de demonstracao nos logs da aplicacao. A resposta
da API devolve o documento mascarado (`**.*22.***/0001-**`). A varredura em `prod`
ainda precisa ser registrada.

## Defeitos corrigidos durante a execucao

Quatro defeitos impediam a telemetria e nenhum aparecia como falha de pipeline —
todos os workflows ficavam verdes enquanto os sinais se perdiam.

| PR | Defeito |
|---|---|
| [auth-serverless #21](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/21) | A layer `AWSOpenTelemetryDistroJava` nao tem collector embutido. A configuracao apontava o exporter para `localhost:4317`, onde nada escuta, e todo sinal era descartado. |
| [infra-kubernetes #14](https://github.com/postech-software-architecture/workshop-infra-kubernetes/pull/14) | O atributo `data` do `kubernetes_secret` ja codifica em base64; o `base64encode` extra gravava a license key codificada duas vezes e a New Relic recusava com HTTP 403. O mesmo PR elevou o hop limit do IMDS para 2, sem o qual os daemonsets do collector nao subiam. |
| [auth-serverless #22](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/22) | A Lambda usava apenas o `db_client_sg`, cujo egress e restrito a porta 5432. Sem saida HTTPS o agente nao alcancava a New Relic. |
| [auth-serverless #24](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/24) | O wrapper da layer reserva dez segundos para o flush final; com o limite da funcao em vinte segundos o flush era abortado junto com a invocacao. |

Dois ajustes de pipeline acompanharam:
[#23](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/23)
tornou o smoke test tolerante ao cold start, e
[soat-architecture #15](https://github.com/postech-software-architecture/soat-architecture/pull/15)
reescreveu os dashboards, que consultavam `FROM Transaction` e nomes do
nrk8s-integration — formatos da stack classica, ausentes numa instalacao
OpenTelemetry.

## Pendencias

**Sinais da Lambda.** Depois dos quatro PRs a funcao respondia corretamente mas os
spans nao apareciam. A causa observada foi propagacao de ENI: a funcao mantinha
seis interfaces, tres com o security group novo e tres apenas com o antigo, sem
egress 443. Invocacoes que caiam nas antigas falhavam o export, o que produzia
falhas intermitentes. As ENIs antigas foram recicladas pela AWS ao fim da janela;
a confirmacao dos spans ficou para a proxima execucao.

**Fluxo de ordem de servico.** O [runbook](../../runbooks/w5-execucao.md) tem o
roteiro com as rotas e payloads verificados. Duas divergencias em relacao ao que
se supunha: o login fica em `/api/auth/login`, nao em `/api/v1/`, e a criacao de
ordem usa `clienteDocumento` e `veiculoPlaca`, nao identificadores.

**State dos assets.** O stack do New Relic rodava sem backend remoto, entao cada
execucao comecava vazia e recriava recursos ja existentes — o segundo apply
duplicou os seis dashboards, removidos depois pela API.
[soat-architecture #16](https://github.com/postech-software-architecture/soat-architecture/pull/16)
corrige isso; antes do primeiro apply com state remoto e preciso importar ou
apagar os dashboards atuais, criados fora de qualquer state.

## Limitacao de fronteira

Access logs do API Gateway permanecem no CloudWatch. A integracao AWS completa do
New Relic nao foi habilitada nesta conta Academy, conforme ressalva do contrato de
observabilidade. Isso nao bloqueia os seis dashboards.
