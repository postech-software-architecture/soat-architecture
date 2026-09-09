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
| ADR-001 | Provedor de nuvem e restricoes do AWS Academy | pendente (depende dos spikes da W0) |
| ADR-002 | Topologia do API Gateway (VPC Link + NLB interno vs. fallback) | pendente (spike da W0) |
| ADR-003 | Segregacao em 4 repositorios | pendente |
| ADR-004 | **Contrato JWT** — claims, algoritmo, dois emissores | pendente (pre-condicao da W4) |
| ADR-005 | Coordenacao de state entre repos (S3 remoto vs. artifact) | pendente (spike da W0) |
| ADR-006 | Observabilidade: **OpenTelemetry + Grafana Cloud** | pendente (substitui a recomendacao de New Relic dos docs) |

## RFCs

| # | Tema | Estado |
|---|---|---|
| RFC-001 | Autenticacao por CPF via Function serverless | stub |
| RFC-002 | Estrategia de observabilidade e metricas de negocio | stub |
| RFC-003 | CI/CD e governanca dos repositorios | stub |

## Evidencias

| Gate | Conteudo |
|---|---|
| [G1](evidence/g1/README.md) | Branch protection, Environments, secret scanning |

## Runbooks

| Runbook | Conteudo |
|---|---|
| [secrets.md](runbooks/secrets.md) | Inventario dos 36 secrets, como preencher, rotacao |

## Ondas e gates

O plano de orquestracao completo (ondas W0–W7, gates G0–G6, caminho critico) vive fora
deste repo, junto aos documentos de planejamento. Resumo:

| Onda | Entrega | Gate |
|---|---|---|
| W0 | Spikes de risco (LabRole, VPC Link, ingest Grafana, tempo de EKS) | G0: veredictos → ADR-001/002/006 |
| W1 | 4 repos, protection, contrato de outputs, CI minima | G1: repos protegidos |
| W2 | `apply` do EKS, k8s → Kustomize, logs JSON | G2: nodes Ready, `verify` verde |
| W3 | RDS com `import`, FKs, uma OpenAPI | G3: pod conecta no RDS |
| W4 | Lambda + API Gateway (A) · JWT + NLB interno (B) | G4: checkpoint E2E 200/401/403 |
| W5 | Collector, 6 dashboards, alertas | G5: alerta disparado |
| W6 | Deploy real, apply com gate | G6: 4 pipelines verdes |
| W7 | Diagramas do ambiente real, video, PDF | entrega |
