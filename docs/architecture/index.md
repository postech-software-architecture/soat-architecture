# Arquitetura — Fase 3

> **[ESTADO.md](ESTADO.md)** — estado executado, pendencias reais e proximo gate.

Indice central da documentacao arquitetural dos quatro repositorios da entrega.

## Repositorios

| Repositorio | Responsabilidade |
|---|---|
| [workshop-service-fase1](https://github.com/postech-software-architecture/workshop-service-fase1) | Aplicacao Spring Boot, migrations e workloads Kubernetes |
| [workshop-infra-kubernetes](https://github.com/postech-software-architecture/workshop-infra-kubernetes) | VPC, EKS, LB Controller e contrato de outputs |
| [workshop-infra-database](https://github.com/postech-software-architecture/workshop-infra-database) | RDS PostgreSQL e state proprio |
| [workshop-auth-serverless](https://github.com/postech-software-architecture/workshop-auth-serverless) | Lambda de autenticacao por CPF, API Gateway e VPC Link |

## RFCs

| # | Tema | Estado |
|---|---|---|
| [RFC-001](rfc/RFC-001-cloud-provider.md) | Provedor de nuvem | aceita |
| [RFC-002](rfc/RFC-002-authentication-strategy.md) | Autenticacao por CPF e fronteira serverless | aceita |
| [RFC-003](rfc/RFC-003-database.md) | PostgreSQL gerenciado e conta inicialmente vazia | aceita |
| [RFC-004](rfc/RFC-004-observability.md) | OpenTelemetry + New Relic US | aceita |

## ADRs

| # | Decisao | Estado |
|---|---|---|
| [ADR-001](adr/ADR-001-aws-academy-labrole.md) | AWS e restricoes do Academy | aceita |
| [ADR-002](adr/ADR-002-api-gateway-vpc-link-nlb.md) | API Gateway com VPC Link + NLB interno | aceita |
| [ADR-003](adr/ADR-003-lambda-cpf-jwt.md) | Lambda de autenticacao por CPF | aceita |
| [ADR-004](adr/ADR-004-jwt-contract.md) | Contrato JWT compartilhado pelos dois emissores | aceita; pre-condicao da W4 satisfeita |
| [ADR-005](adr/ADR-005-backend-terraform-remoto.md) | State remoto com S3 + DynamoDB | aceita |
| [ADR-006](adr/ADR-006-opentelemetry-new-relic.md) | OpenTelemetry + New Relic US | aceita |

## Evidencias e runbooks

| Item | Conteudo |
|---|---|
| [G1](evidence/g1/README.md) | Branch protection, Environments e secret scanning |
| [W0/W2](evidence/w0-w2/README.md) | Spikes, EKS, aplicacao instrumentada e destroy |
| [W3](evidence/w3/README.md) | Integridade, OpenAPI, RDS e pendencias do Gate G3 |
| [Secrets](runbooks/secrets.md) | Inventario, renovacao e rotacao |

## Dados — W3

| Item | Conteudo |
|---|---|
| [Diagrama ER](diagrams/database-er.mmd) | Fonte Mermaid de 16/17 tabelas; `webhook_eventos_processados` nao participa de relacoes; SVG/PNG pendentes |
| [Escolha do banco](database/database-choice.md) | PostgreSQL no RDS, alternativas e concessoes do Academy |
| [Relacionamentos](database/relationships.md) | Ownership, obrigatoriedade, `ON DELETE` e indices |
| [Revisao de performance](database/performance-review.md) | Consultas, indices e checkpoint reprodutivel de `EXPLAIN` |
| [OpenAPI canônica](https://github.com/postech-software-architecture/workshop-service-fase1/blob/main/openapi.yaml) | Unica fonte de runtime: OpenAPI 3.1 na raiz; copia de `src` ausente e specs historicas nao publicadas |

## Ondas e gates

O plano completo de orquestracao (W0–W7, G0–G6 e caminho critico) permanece junto aos
documentos de planejamento. Este resumo registra o estado executado:

| Onda | Entrega | Gate |
|---|---|---|
| W0 | quatro spikes de risco | **concluida** |
| W1 | repositorios, protecoes, outputs, CI, RFCs e ADRs | **concluida** |
| W2 | EKS/Kustomize, LB Controller, logs JSON/OTLP, correlacao e destroy | **concluida** |
| W3 | RDS novo, FKs, uma OpenAPI e documentacao de dados | **em execucao; G3 aberto** |
| W4 | Lambda + API Gateway; JWT + NLB interno | G4: 200/401/403 e sem bypass |
| W5 | Collector, seis dashboards e alertas | G5: alerta disparado |
| W6 | pipelines de deploy e governanca finais | G6: quatro pipelines verdes |
| W7 | diagramas reais, video e PDF | entrega |

Na conta AWS atual nao existe RDS legado. Import e auditoria de dados persistidos sao
condicionais ao inventario e, com a conta vazia, ficam `N/A`; a W3 cria o banco do zero.
