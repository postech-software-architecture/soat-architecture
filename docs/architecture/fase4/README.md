# Fase 4 — documentação consolidada e evidências reais

Atualizado em **15/11/2026**, horário de São Paulo. A conferência final de cobertura, qualidade, CI/CD e main dos três microserviços foi concluída nas versões implantadas. Vídeo e PDF institucional ficaram para o solicitante no dia seguinte e **não estão declarados como entregues**.

| Serviço | Testes Maven | Cobertura LINE | CI da versão | Deploy independente |
|---|---:|---:|---|---|
| workshop-os-service | 387 | 83.31% | [CI](https://github.com/postech-software-architecture/workshop-os-service/actions/runs/43743930446) | [Deploy](https://github.com/postech-software-architecture/workshop-os-service/actions/runs/43744057933) |
| workshop-billing-service | 111 | 85.43% | [CI](https://github.com/postech-software-architecture/workshop-billing-service/actions/runs/43773150621) | [Deploy](https://github.com/postech-software-architecture/workshop-billing-service/actions/runs/43774200032) |
| workshop-execution-service | 77 | 86.95% | [CI](https://github.com/postech-software-architecture/workshop-execution-service/actions/runs/43652212164) | [Deploy](https://github.com/postech-software-architecture/workshop-execution-service/actions/runs/43653172074) |

São **575 testes Maven**, sem falhas, erros ou skips, e SpotBugs sem achados nos três relatórios. A métrica exigida pelo gate é **LINE ≥80%**; não alegamos 80% de branches. As suítes incluem testes unitários, de contexto e BDD por serviço; [detalhes e contadores](evidencias/qualidade-ci.json).

## Navegação da entrega

- [Arquitetura, divisão de domínios, tecnologias e Saga](ARQUITETURA-E-SAGA.md).
- [Verificação de qualidade, CI/CD e proteções](CONFERENCIA-FINAL.md).
- [BDD completo com pagamento real de teste](BDD.md).
- [Observabilidade e limites da evidência](OBSERVABILIDADE.md).
- [Matriz dos requisitos e o que ainda falta](ACEITE-E-ENTREGA.md).
- [Retomada amanhã](RETOMADA.md).
- [Resumo para compartilhar com a equipe](RESUMO-PARA-EQUIPE.md).

## Resultados funcionais

| Cenário | Resultado real |
|---|---|
| OS 09 — pagamento e reparo | Billing CONFIRMADO, provedor processed/accredited, trabalho CONCLUIDO, OS ENTREGUE; repetição de entrega idempotente |
| OS 07 — cancelar sem pagar | Orçamento e trabalho CANCELADO, OS COMPENSADA; aprovação tardia recusada e estoque devolvido uma vez |
| OS 10 — cancelar após pagar | Billing ESTORNADO, provedor refunded, trabalho CANCELADO, OS COMPENSADA; estoque 43 → 45,5, sem segunda devolução |
| OS 06 — falha automática histórica | 19 retries de criação financeira com gateway desativado, motivo PARTICIPANT_DEADLINE, pagamento CANCELADO e compensação automática |
| OS 11 — BDD integrado | 1 cenário/5 passos, zero falhas/skips, dry-run=false; pagamento real de teste e mesma OS/tentativa/trabalho até ENTREGUE |

Os cenários HTTP consolidados tiveram 210 requests/422 asserções aprovadas, incluindo polling assíncrono. Isso não deve ser somado ao total de testes Maven ou confundido com o cenário Cucumber.

## Repositórios e contratos

| Domínio / apoio | Repositório |
|---|---|
| OS, catálogo, estoque e coordenador Saga | [workshop-os-service](https://github.com/postech-software-architecture/workshop-os-service) |
| Orçamento e pagamentos | [workshop-billing-service](https://github.com/postech-software-architecture/workshop-billing-service) |
| Diagnóstico e reparo | [workshop-execution-service](https://github.com/postech-software-architecture/workshop-execution-service) |
| Runtime, broker, Mongo, BDD e centralização | [workshop-infra-platform](https://github.com/postech-software-architecture/workshop-infra-platform) |
| Auth e API Gateway | [workshop-auth-serverless](https://github.com/postech-software-architecture/workshop-auth-serverless) |
| EKS e rede | [workshop-infra-kubernetes](https://github.com/postech-software-architecture/workshop-infra-kubernetes) |
| RDS | [workshop-infra-database](https://github.com/postech-software-architecture/workshop-infra-database) |
| Documentação central | [soat-architecture](https://github.com/postech-software-architecture/soat-architecture) |

O monólito da Fase 3 permanece como histórico. O gateway atual usa `https://rnwyojgeaa.execute-api.us-east-1.amazonaws.com/prod` com `/api/auth` e `/api/v1`; não acrescentar prefixos de Compose. Os contratos OpenAPI e de mensagens ficam nos repositórios dos serviços. Por orientação do solicitante, collections e environment Postman ficam **somente locais**.
