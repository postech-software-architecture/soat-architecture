# ADR-002 — API Gateway com VPC Link e NLB interno

**Estado:** aceito em 2026-09-12

## Decisao

Usar o API Gateway como unica borda publica. As rotas de aplicacao atravessam um
VPC Link e um NLB interno antes de chegar aos workloads no EKS. O NLB nao deve
oferecer acesso publico direto.

## Evidencia

O [workflow 34716577120](https://github.com/postech-software-architecture/workshop-auth-serverless/actions/runs/34716577120)
criou um backend temporario no EKS, um NLB interno, um VPC Link e uma HTTP API.
O VPC Link chegou a `AVAILABLE` e a chamada pela URL publica do API Gateway
atravessou o caminho privado e respondeu HTTP 200. A rotina removeu os recursos
temporarios sem avisos.

O ensaio anterior identificou `NoCredentialProviders` no Load Balancer Controller.
No AWS Academy, onde IRSA e Pod Identity nao podem ser configurados livremente, o
controller usa `hostNetwork` para obter a `LabRole` do node via IMDS. A excecao fica
restrita ao controller, com uma replica e rollout `Recreate`.

## Consequencias

- A W4-A implementa o API Gateway e o VPC Link conforme esta topologia.
- A W4-B publica a aplicacao por Service `LoadBalancer` com NLB interno.
- A ausencia de acesso direto ao NLB integra o checkpoint sem bypass do G4.
- Em conta AWS convencional, substituir o fallback do Academy por IRSA ou EKS Pod Identity.
