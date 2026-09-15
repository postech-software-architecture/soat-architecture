# soat-architecture

> Repositorio de **arquitetura e governanca** da **Fase 3** do Tech Challenge (SOAT).
> Nao contem codigo de aplicacao nem infraestrutura executavel: e a fonte unica das
> decisoes (ADR/RFC), do modelo de dados, do contrato de observabilidade e das
> evidencias de entrega dos demais repositorios.

---

## Proposito

A Fase 3 foi segregada em quatro repositorios com ciclos de vida independentes. Este
repositorio e o **centro documental** que os coordena:

| Responsabilidade | Detalhe |
|---|---|
| **Decisoes de arquitetura** | ADRs e RFCs que justificam cloud provider, estrategia de autenticacao, banco e observabilidade |
| **Modelo de dados** | Modelo logico, relacionamentos e diagrama ER do dominio de oficina |
| **Contrato de observabilidade** | Metricas, traces e logs esperados de cada servico, mais os dashboards New Relic como IaC |
| **Estado da entrega** | Estado corrente, pendencias e proximo passo de cada onda (W0–W5) |
| **Evidencias** | Artefatos comprobatorios por onda e por gate (G1…), incluindo protecoes de branch e environments |

O que **nao** vive aqui: Terraform de cluster ou banco, codigo da Lambda de autenticacao
e codigo da API de oficina. Cada um tem seu proprio repositorio.

### Repositorios da Fase 3

| Repositorio | Papel |
|---|---|
| [soat-architecture](https://github.com/postech-software-architecture/soat-architecture) | Arquitetura, ADR/RFC, evidencias, dashboards New Relic *(este repo)* |
| [workshop-infra-kubernetes](https://github.com/postech-software-architecture/workshop-infra-kubernetes) | VPC, EKS, node group, add-ons — **autora o contrato de outputs** |
| [workshop-infra-database](https://github.com/postech-software-architecture/workshop-infra-database) | RDS PostgreSQL privado, state proprio |
| [workshop-auth-serverless](https://github.com/postech-software-architecture/workshop-auth-serverless) | Lambda de autenticacao por CPF + API Gateway (borda unica) |
| [workshop-service-fase1](https://github.com/postech-software-architecture/workshop-service-fase1) | API REST de gestao de oficinas (Spring Boot) |

---

## Tecnologias utilizadas

| Camada | Tecnologia |
|---|---|
| Documentacao | Markdown, ADR/RFC, Mermaid (`.mmd`) para diagramas versionados |
| Observabilidade como codigo | Terraform + provider New Relic, dashboards em templates `.json.tftpl` |
| Automacao | GitHub Actions (`ci.yml` para lint/validacao documental, `newrelic-assets.yml` para os dashboards) |
| Governanca | GitHub Environments, branch protection e evidencias versionadas em JSON |

---

## Estrutura

```text
docs/architecture/
├── index.md                  → indice de navegacao da arquitetura
├── ESTADO.md                 → estado corrente, pendencias e proximo passo
├── adr/                      → decisoes aceitas (ADR-001..006)
├── rfc/                      → propostas discutidas (RFC-001..004)
├── data/ e database/         → modelo de dados, relacionamentos e escolha do banco
├── diagrams/                 → diagramas versionados (ER em Mermaid)
├── observability/            → contrato W5 + dashboards New Relic (Terraform)
├── runbooks/                 → secrets, setup New Relic, execucao da W5
└── evidence/                 → evidencias por onda (w0-w2, w3, w4, w5) e por gate (g1)
```

### Decisoes registradas

| ADR | Decisao |
|---|---|
| ADR-001 | Uso exclusivo da `LabRole` no AWS Academy (IAM bloqueado) |
| ADR-002 | Borda via API Gateway + VPC Link para NLB interno |
| ADR-003 | Autenticacao por CPF em Lambda emitindo JWT |
| ADR-004 | Contrato do JWT compartilhado entre Lambda e aplicacao |
| ADR-005 | Backend Terraform remoto em S3 com lock em DynamoDB |
| ADR-006 | OpenTelemetry exportando para New Relic |

---

## Como executar

Este repositorio nao expoe um servico. As operacoes disponiveis sao a validacao da
documentacao e o apply dos dashboards de observabilidade.

### 1. Validacao local da documentacao

```bash
git clone git@github.com:postech-software-architecture/soat-architecture.git
cd soat-architecture

# leia o estado corrente antes de iniciar qualquer onda
cat docs/architecture/ESTADO.md
```

O workflow `ci.yml` roda automaticamente em push/PR e valida a consistencia documental.

### 2. Deploy dos dashboards New Relic

Os dashboards sao versionados como templates Terraform e aplicados pelo workflow
`newrelic-assets.yml` (`workflow_dispatch`, Environment `prod`).

```bash
cd docs/architecture/observability/newrelic/terraform

terraform init
terraform plan    # requer NEW_RELIC_API_KEY e NEW_RELIC_ACCOUNT_ID
terraform apply
```

Secrets necessarios no Environment `prod`: `NEW_RELIC_API_KEY` e `NEW_RELIC_ACCOUNT_ID`.
O runbook completo esta em
[`docs/architecture/runbooks/newrelic-setup.md`](docs/architecture/runbooks/newrelic-setup.md).
Nunca registre chaves reais neste repositorio — consulte o
[runbook de secrets](docs/architecture/runbooks/secrets.md).

Dashboards provisionados:

| Dashboard | Escopo |
|---|---|
| `01-service-overview` | Visao geral do servico |
| `02-order-lifecycle` | Ciclo de vida da ordem de servico |
| `03-order-reliability` | Confiabilidade do fluxo de pedidos |
| `04-auth-serverless` | Autenticacao por CPF (Lambda) |
| `05-eks-infrastructure` | Infraestrutura do cluster EKS |
| `06-dependencies-correlation` | Correlacao entre dependencias |

---

## Diagrama da arquitetura

<!-- TODO: inserir o diagrama de arquitetura consolidada da Fase 3.
     Sugestao: exportar para docs/architecture/diagrams/ e referenciar aqui. -->

```text
[ reservado para o diagrama de arquitetura consolidada da Fase 3 ]
```

> Diagrama ER do modelo de dados ja disponivel em
> [`docs/architecture/diagrams/database-er.mmd`](docs/architecture/diagrams/database-er.mmd).

---

## APIs — Swagger / Postman

Este repositorio nao expoe API propria. As especificacoes das APIs da Fase 3 vivem nos
repositorios que as implementam:

| API | Especificacao |
|---|---|
| Autenticacao por CPF (Lambda) | [`workshop-auth-serverless/docs/openapi-auth.yaml`](https://github.com/postech-software-architecture/workshop-auth-serverless/blob/main/docs/openapi-auth.yaml) |
| Workshop Service (API REST) | [`workshop-service-fase1/openapi.yaml`](https://github.com/postech-software-architecture/workshop-service-fase1/blob/main/openapi.yaml) — Swagger UI em `/swagger-ui.html` com a aplicacao no ar |

<!-- TODO: adicionar link da collection Postman consolidada da Fase 3, se publicada. -->

---

## Agentes

Ver [.claude/agents/README.md](.claude/agents/README.md).
