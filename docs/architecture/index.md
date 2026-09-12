# Arquitetura — Fase 3

> **[ESTADO.md](ESTADO.md)** — o que esta pronto, o que falta e os riscos abertos.
> Levantamento verificado no codigo, atualizado a cada onda.

Indice central da documentacao arquitetural. Este repositorio agrega a visao dos
**4 repositorios** da entrega; cada um mantem o seu proprio README.

## Repositorios

| Repositorio | Responsabilidade |
|---|---|
| [workshop-service-fase1](https://github.com/postech-software-architecture/workshop-service-fase1) | Aplicacao Spring Boot, migrations, manifestos k8s |
| [workshop-infra-kubernetes](https://github.com/postech-software-architecture/workshop-infra-kubernetes) | VPC, EKS, LB Controller, **contrato de outputs** |
| [workshop-infra-database](https://github.com/postech-software-architecture/workshop-infra-database) | RDS PostgreSQL, state proprio |
| [workshop-auth-serverless](https://github.com/postech-software-architecture/workshop-auth-serverless) | Lambda de autenticacao por CPF, API Gateway, VPC Link |

## ADRs

| # | Decisao | Estado |
|---|---|---|
| [ADR-001](adr/ADR-001-aws-academy-labrole.md) | Provedor de nuvem e restricoes do AWS Academy | aceito: LabRole aprovada para Lambda |
| [ADR-002](adr/ADR-002-api-gateway-vpc-link-nlb.md) | Topologia do API Gateway com VPC Link + NLB interno | aceito: caminho privado respondeu HTTP 200 |
| ADR-003 | Segregacao em 4 repositorios | pendente |
| ADR-004 | **Contrato JWT** — claims, algoritmo, dois emissores | pendente (pre-condicao da W4) |
| [ADR-005](adr/ADR-005-backend-terraform-remoto.md) | Coordenacao de state entre repos com S3 + DynamoDB | aceito: backend reutilizado por applies reais |
| [ADR-006](adr/ADR-006-opentelemetry-new-relic.md) | Observabilidade: **OpenTelemetry + New Relic US** | aceito: ingestao OTLP comprovada |

## RFCs

| # | Tema | Estado |
|---|---|---|
| RFC-001 | Autenticacao por CPF via Function serverless | stub |
| RFC-002 | Estrategia de observabilidade e metricas de negocio | stub |
| RFC-003 | CI/CD e governanca dos repositorios | stub |

## Evidencias

| Gate | Conteudo |
|---|---|
| [G1](evidence/g1/README.md) | Snapshot de branch protection, Environments e secret scanning em 2026-09-08 |
| [W0/W2](evidence/w0-w2/README.md) | Consolidacao dos PRs e validacao manual do EKS/Kustomize |

## Runbooks

| Runbook | Conteudo |
|---|---|
| [secrets.md](runbooks/secrets.md) | Inventario dos 18 secrets, como preencher e rotacionar |

## Ondas e gates

O plano de orquestracao completo (ondas W0–W7, gates G0–G6, caminho critico) vive fora
deste repo, junto aos documentos de planejamento. Resumo:

| Onda | Entrega | Gate |
|---|---|---|
| W0 | EKS/backend, LabRole, OTLP/New Relic e VPC Link aprovados | G0 concluido: ADR-001/002/005/006 |
| W1 | 4 repos, protection, contrato de outputs, CI minima | G1 parcial: secrets reais e ADRs pendentes |
| W2 | EKS e Kustomize validados; logs/higiene pendentes | G2 parcial: nodes Ready ja demonstrados; `verify` ainda requerido |
| W3 | RDS com `import`, FKs, uma OpenAPI | G3: pod conecta no RDS |
| W4 | Lambda + API Gateway (A) · JWT + NLB interno (B) | G4: checkpoint E2E 200/401/403 |
| W5 | Collector, 6 dashboards, alertas | G5: alerta disparado |
| W6 | Deploy real, apply com gate | G6: 4 pipelines verdes |
| W7 | Diagramas do ambiente real, video, PDF | entrega |
