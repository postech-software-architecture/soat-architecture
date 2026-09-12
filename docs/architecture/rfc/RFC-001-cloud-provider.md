# RFC-001 — Provedor de nuvem

- **Status:** aceita
- **Autores:** Grupo SOAT
- **Data:** 2026-09-12

## Contexto

A entrega exige Kubernetes gerenciado, banco relacional, funcao serverless, API Gateway,
rede privada e pipelines reproduziveis. O laboratorio disponivel para o grupo e o AWS
Academy, com credenciais temporarias e a `LabRole` como role utilizavel.

## Problema

Escolher um provedor que permita demonstrar toda a topologia no ambiente academico sem
criar dependencias que o laboratorio nao autoriza.

## Requisitos e restricoes

- Kubernetes, PostgreSQL gerenciado, Lambda e API Gateway;
- automacao por Terraform e GitHub Actions;
- compatibilidade com a `LabRole` e credenciais com session token;
- custo controlado e destroy ao fim de cada janela.

## Opcoes consideradas

1. AWS com EKS, RDS, Lambda e API Gateway.
2. Azure com AKS, Azure Database e Functions.
3. GCP com GKE, Cloud SQL e Cloud Functions.

## Comparacao

As tres alternativas atendem tecnicamente ao desenho. Somente a AWS possui conta de
laboratorio, role e creditos ja fornecidos ao grupo. Migrar de provedor acrescentaria
cadastro, custo e uma segunda trilha de aprendizado sem beneficio para os requisitos.

## Proposta aceita

Usar AWS em `us-east-1`, com Terraform por camada e adaptacoes explicitas para as
restricoes do AWS Academy.

## Impactos

- credenciais precisam ser renovadas por janela;
- recursos caros devem ser destruidos ao final;
- IAM avancado pode exigir fallback especifico do Academy;
- a decisao e registrada definitivamente no ADR-001.

## Questoes em aberto

Nenhuma para W0–W2. Melhorias de IAM para uma conta AWS convencional ficam fora do escopo.
