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
| 1 | Seis dashboards com dados reais | **28 de 31 widgets** — ver tabela abaixo |
| 2 | Trace HTTP com span JDBC | **atendido** |
| 3 | Mesmo `correlationId` na Lambda e na aplicacao | **parcial** — o identificador aparece nos logs das duas pontas, mas nao ha trace unico ligando-as, porque traces da Lambda nao chegam |
| 4 | Incidente aberto por falha controlada | pendente — as tres transicoes invalidas foram executadas e devolveram 422; falta confirmar a abertura do incidente |
| 5 | Notificacao entregue | pendente |
| 6 | Incidente recuperado | pendente |
| 7 | Busca sem CPF, JWT, senha ou segredo | **parcial** — ver higiene |

O fluxo foi exercitado contra o ambiente em 2026-09-15: autenticacao por CPF na
Lambda devolvendo 200 com JWT para documento valido e 422 para invalido, com e sem
mascara; login dos tres usuarios de demonstracao; criacao da ordem `OS-2026-00001`;
diagnostico iniciado e encerrado; e tres tentativas de transicao invalida, todas
com 422. O JWT emitido carrega `roles`, emissor, audiencia e expiracao de uma hora,
e nao contem o CPF.

### Dashboards

Os 31 widgets foram executados contra a conta: nenhum tem erro de sintaxe.

| Dashboard | Widgets com dados |
|---|---|
| W5 - Auth Serverless | 4/4 |
| W5 - EKS Infrastructure | 7/7 |
| W5 - Service Overview | 6/6 |
| W5 - Dependencies and Correlation | 5/6 |
| W5 - Ordem de Servico Lifecycle | 3/4 |
| W5 - Ordem de Servico Reliability | 3/4 |
| **total** | **28/31** |

Medido apos exercitar os endpoints: autenticacao por CPF na Lambda com documento
valido e invalido, login dos usuarios de demonstracao, criacao de ordem de
servico, diagnostico iniciado e encerrado, tres transicoes invalidas e chamadas
sem token para produzir resposta 4xx.

O painel da Lambda fechou depois de trocar os dois widgets de span por metricas
(ver "Traces da Lambda" abaixo): a duracao vem do histograma
`workshop.auth.cpf.duration`, medido no handler, e as falhas somam os contadores
de CPF e de banco. Amostra da execucao: p50 4,1 ms e p95 774 ms, este ultimo
refletindo o cold start.

Os tres widgets ainda vazios dependem de sinais que esta execucao nao produziu:
duracao por etapa exige uma ordem de servico atravessando execucao e entrega,
erros de integracao exigem falha de e-mail ou webhook, e a busca por
`correlationId` no log so retorna quando a aplicacao registra a requisicao em
nivel informativo.

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
| [auth-serverless #25](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/25) | O endpoint apontava para a porta 4318 e o security group libera saida apenas na 443. Uma funcao-sonda nas mesmas subnets mediu: 4318 expira, 443 conecta. A New Relic serve o mesmo OTLP nas duas, entao bastou remover a porta explicita. |
| [auth-serverless #26](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/26) | A Lambda injeta `_X_AMZN_TRACE_ID` com `Sampled=0` e o propagador xray o aceita como pai valido nao amostrado; o sampler padrao respeitava esse pai e descartava o span raiz. Corrigido com `OTEL_TRACES_SAMPLER=always_on`. |
| [auth-serverless #29](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/29) | A duracao do handler passou a ser emitida como metrica, porque o painel de latencia lia spans que nao chegam. |

Nenhum desses defeitos reprovou uma pipeline: todos os workflows ficavam verdes
enquanto os sinais se perdiam. A unica forma de detecta-los foi consultar a conta
por NRQL apos cada deploy, e e o que vale manter como pratica nas ondas seguintes.

Dois ajustes de pipeline acompanharam:
[#23](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/23)
tornou o smoke test tolerante ao cold start, e
[soat-architecture #15](https://github.com/postech-software-architecture/soat-architecture/pull/15)
reescreveu os dashboards, que consultavam `FROM Transaction` e nomes do
nrk8s-integration — formatos da stack classica, ausentes numa instalacao
OpenTelemetry.

## Pendencias

**Traces da Lambda nao chegam, metricas e logs chegam.** A investigacao passou por
seis correcoes antes de isolar o que realmente acontece, e o diagnostico veio de
rodar a funcao com `OTEL_TRACES_EXPORTER=logging`, que imprime no CloudWatch os
spans produzidos. Apareceram dois por invocacao:

```
'POST POST /api/auth/cpf' ... [tracer: workshop-auth-serverless]
'workshop-auth-cpf'       ... [tracer: io.opentelemetry.aws-lambda-events-2.2]
```

Duas conclusoes. A instrumentacao da camada **atacha** neste handler e cria o span
da invocacao, inclusive para `APIGatewayV2HTTPEvent` — ao contrario do que se
supunha durante a investigacao. E o span nunca sai: nao ha erro de export no log,
enquanto metricas e logs atravessam o mesmo endpoint OTLP normalmente.

O primeiro span daquela lista era uma tentativa de criar o span manualmente na
fachada, revertida depois deste teste por ser duplicata — e com defeito, porque
`routeKey` ja contem o metodo e o codigo o concatenava outra vez.

Como a lacuna e de export e nao de instrumentacao, os dois paineis que liam
`FROM Span` passaram a ler metricas. Isso os alimenta com o mesmo comportamento
por um sinal que comprovadamente chega, e o dashboard fechou 4/4.

Traces da Lambda seguem indisponiveis. Isso afeta o criterio de correlacao do G5,
que pede o mesmo `correlationId` visivel na Lambda e na aplicacao: o
`correlationId` aparece nos logs das duas pontas, mas nao ha trace unico ligando
as duas. Registrar como limitacao da camada nesta versao.

**Fluxo de ordem de servico.** O [runbook](../../runbooks/w5-execucao.md) tem o
roteiro com as rotas e payloads verificados. Duas divergencias em relacao ao que
se supunha: o login fica em `/api/auth/login`, nao em `/api/v1/`, e a criacao de
ordem usa `clienteDocumento` e `veiculoPlaca`, nao identificadores.

**State dos assets.** O stack do New Relic roda sem backend remoto, entao cada
execucao comeca vazia e recria recursos que ja existem. Ja duplicou os seis
dashboards uma vez e, na execucao mais recente, tres politicas de alerta; em
ambos os casos as copias foram removidas pela API. Antes de cada apply e preciso
apagar o que ja existe, ou o apply falha com `DUPLICATE` no meio e deixa recursos
a mais.
[soat-architecture #16](https://github.com/postech-software-architecture/soat-architecture/pull/16)
corrige isso; antes do primeiro apply com state remoto e preciso importar ou
apagar os dashboards atuais, criados fora de qualquer state.

## Limitacao de fronteira

Access logs do API Gateway permanecem no CloudWatch. A integracao AWS completa do
New Relic nao foi habilitada nesta conta Academy, conforme ressalva do contrato de
observabilidade. Isso nao bloqueia os seis dashboards.
