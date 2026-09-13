# Contrato de observabilidade — W5

**Estado:** aceito para implementação da W5  
**Decisão de referência:** [ADR-006](../adr/ADR-006-opentelemetry-new-relic.md)  
**Backend:** New Relic US, por OTLP

## Objetivo

Este contrato fixa o vocabulário de traces, logs, métricas, dashboards e alertas da W5.
O código usa OpenTelemetry; o New Relic US recebe, consulta e alerta sobre os sinais.
Nenhum produtor deve chamar uma API proprietária do New Relic quando houver equivalente
OpenTelemetry.

## Serviços e atributos de recurso

| Recurso | Valor obrigatório |
|---|---|
| `service.name` da aplicação Spring | `workshop-service` |
| `service.name` da Lambda | `workshop-auth-serverless` |
| `deployment.environment` | `prod` |
| `service.version` | SHA curto ou versão imutável do artefato implantado |
| `k8s.cluster.name` | `workshop-eks`, para sinais do Kubernetes |

Todo log JSON de produção deve conter `correlationId`; quando houver contexto de trace,
deve conter também `trace.id` e `span.id`. O `X-Correlation-ID` recebido deve atravessar
Lambda, API Gateway e aplicação. Se estiver ausente, o produtor pode gerar um UUID. A
ausência de contexto de trace não pode impedir uma requisição de funcionar.

## Privacidade e cardinalidade

As únicas tags de domínio permitidas são `status`, `stage`, `operation`, `integration`,
`outcome` e `environment`. Atributos técnicos OpenTelemetry, como `service.name`,
`deployment.environment`, `http.request.method`, `http.response.status_code`, `db.system`
e identificadores de recurso Kubernetes, também são permitidos.

CPF completo ou mascarado, JWT, senha, segredo, e-mail, nome de cliente, ID de usuário,
ID de OS, payload, query SQL com valores e mensagem de exceção são proibidos em tags,
logs, spans, `baggage`, métricas, dashboards, alertas e artefatos de workflow.
`correlationId`, `trace.id` e `span.id` servem apenas para logs/traces e não podem ser
dimensões de métricas.

## Métricas de negócio

Os nomes abaixo são exatos. `*.count` é contador monotônico; duração é histograma em
segundos. Toda métrica recebe `environment=prod`.

| Métrica | Tipo | Produtor | Quando registrar |
|---|---|---|---|
| `workshop.ordem_servico.created.count` | contador | aplicação | OS criada após commit da transação |
| `workshop.ordem_servico.status.duration` | histograma | aplicação | etapa concluída a partir do histórico persistido |
| `workshop.ordem_servico.processing.error.count` | contador | aplicação | falha na criação ou transição de OS |
| `workshop.integration.error.count` | contador | aplicação | erro de e-mail ou webhook |
| `workshop.auth.cpf.attempt.count` | contador | Lambda | tentativa após parse seguro |
| `workshop.auth.cpf.failure.count` | contador | Lambda | tentativa inválida, inelegível ou com erro controlado |

Métricas de OS podem usar `stage`, `operation`, `status` e `outcome`; integrações usam
`integration` e `outcome`; CPF usa `operation=cpf` e `outcome`. Documento informado nunca
é uma dimensão.

### Etapas formais de ordem de serviço

A duração mede tempo de negócio, não duração HTTP; a fonte é o histórico persistido.

| `stage` | Início | Fim |
|---|---|---|
| `diagnostico` | entrada em `EM_DIAGNOSTICO` | primeira saída desse status |
| `execucao` | entrada em `EM_EXECUCAO` | entrada em `FINALIZADA` |
| `finalizacao` | entrada em `FINALIZADA` | entrada em `ENTREGUE` |

Etapa incompleta não produz duração. O cálculo ocorre depois de a transação persistir o
histórico com sucesso.

## Sinais técnicos obrigatórios

- A aplicação produz trace HTTP e span JDBC com OpenTelemetry Java Agent.
- A Lambda produz trace e logs JSON pelo collector ADOT embarcado.
- O Collector NRDOT no EKS coleta CPU, memória, reinícios, réplicas, pods não prontos e
  HPA, além dos logs stdout dos workloads.
- Healthchecks não entram nos painéis de tráfego, latência ou erro.
- Exporters ficam desligados por padrão em testes e execução local.

## Dashboards obrigatórios

Os seis dashboards são exportáveis/reimportáveis e devem ter título, descrição, filtro
`deployment.environment = 'prod'`, período explícito e link de runbook.

| # | Dashboard | Conteúdo mínimo |
|---|---|---|
| 1 | `API latency` | volume, taxa de erro e p50/p95/p99 da aplicação e Lambda; sem healthchecks |
| 2 | `Kubernetes resources` | CPU, memória, pods não prontos, reinícios, réplicas e HPA |
| 3 | `Health and uptime` | sintético do API Gateway, health e falhas recentes |
| 4 | `Daily service orders` | `COUNT(*)` diário e `workshop.ordem_servico.created.count` |
| 5 | `Service-order stage duration` | p50/p95 de `diagnostico`, `execucao` e `finalizacao` |
| 6 | `Integration and authentication errors` | e-mail/webhook, CPF, Lambda e taxa de erro por operação |

Os dashboards 1 e 6 incluem a Lambda. O dashboard 3 monitora a URL pública do API
Gateway, nunca o DNS interno do NLB.

## Alerta mínimo e G5

O alerta obrigatório é **falhas de processamento de ordem de serviço**: abrir incidente
com **três ou mais** ocorrências de `workshop.ordem_servico.processing.error.count` em
**cinco minutos** no ambiente `prod`. A condição precisa exibir métrica, `service.name`,
ambiente, janela, limiar e runbook; deve notificar um canal configurado e recuperar quando
a condição cessar.

G5 exige evidência versionada de:

1. seis dashboards com dados reais;
2. trace HTTP da aplicação contendo span JDBC;
3. uma operação localizável por `correlationId` nos sinais Lambda e aplicação;
4. alerta aberto por falha controlada, notificação entregue e recuperação posterior;
5. busca global sem CPF, JWT, senha ou segredo;
6. exports, NRQL, capturas e runbooks sanitizados.

## Matriz sinal → produtor → consumo

| Sinal | Produtor | Destino/consulta | Dashboard | Alerta |
|---|---|---|---|---|
| latência, volume e erro HTTP | Java Agent e ADOT | traces/métricas OTLP | 1, 6 | não obrigatório na W5 |
| span JDBC | Java Agent da aplicação | trace OTLP | 1 (link para trace) | não |
| CPU, memória, pods, réplicas, restart e HPA | NRDOT no EKS | métricas de infraestrutura | 2 | não obrigatório na W5 |
| disponibilidade pública | sintético contra API Gateway | Synthetic + health | 3 | não obrigatório na W5 |
| OS criada | adapter da aplicação | `workshop.ordem_servico.created.count` | 4 | não |
| duração por etapa | adapter da aplicação | `workshop.ordem_servico.status.duration` | 5 | não |
| falha de OS | adapter da aplicação | `workshop.ordem_servico.processing.error.count` | 6 | sim, 3 em 5 min |
| falha e-mail/webhook | adapter de integrações | `workshop.integration.error.count` | 6 | não obrigatório na W5 |
| tentativa/falha CPF | Lambda | `workshop.auth.cpf.*` | 6 | não obrigatório na W5 |
| investigação ponta a ponta | Lambda e aplicação | logs/traces por `correlationId` | 1 e 6 | não |

## Fronteira do AWS Academy

Os access logs do API Gateway permanecem ativos no CloudWatch. A integração AWS completa
do New Relic para esses logs só será configurada se permissões e duração do AWS Academy
permitirem. Caso não permitam, CloudWatch é a fonte operacional desse trecho e a limitação
deve constar na evidência G5. Isso não substitui logs, métricas e traces OTLP da Lambda e
aplicação, nem bloqueia os seis dashboards quando os demais dados existirem.
