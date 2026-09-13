# W4 — autenticação serverless e borda privada · evidência de execução

Execução realizada na AWS Academy em 2026-09-13. Segredos, CPF, JWT, senha de banco,
DNS efêmero e identificadores de recursos não são versionados neste registro.

**Situação:** G4 concluído. A W5 está liberada. A dívida de `EXPLAIN (ANALYZE, BUFFERS)`
permanece pertencente à W3 e não é transferida para esta onda.

---

## Entrega

- Lambda Java 21 `workshop-auth-cpf` em subnets privadas, com `LabRole`, acesso ao RDS
  pela identidade `db_client_sg_id`, timeout de 20 s, 1024 MB, tracing ativo e alias `prod`;
- `POST /api/auth/cpf` no API Gateway HTTP API, com CPF validado antes da consulta ao banco;
- JWT HS256 de uma hora com `iss=workshop-auth`, `aud=workshop-service`, `sub`, `username`,
  `roles`, `jti`, `iat` e `exp`;
- rota `$default` do Gateway para o listener do NLB interno, por VPC Link;
- NLB `workshop-api-internal`, sem exposição direta à internet;
- state Terraform remoto próprio do serverless em `serverless/terraform.tfstate`.

## Pull requests integrados

| Repositório | PRs W4 | Resultado |
|---|---|---|
| `workshop-service-fase1` | [#70](https://github.com/postech-software-architecture/workshop-service-fase1/pull/70), [#71](https://github.com/postech-software-architecture/workshop-service-fase1/pull/71) | NLB interno e contrato JWT na aplicação |
| `workshop-auth-serverless` | [#4](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/4), [#5](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/5), [#6](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/6), [#7](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/7), [#8](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/8), [#9](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/9), [#10](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/10) | núcleo, handler, Terraform, pipeline, backend remoto e alias |
| `workshop-auth-serverless` | [#11](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/11), [#12](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/12), [#13](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/13), [#14](https://github.com/postech-software-architecture/workshop-auth-serverless/pull/14) | correções de handler, URL JDBC, contrato JSON e caminho do VPC Link, reveladas pelos testes reais |

## Pipelines e infraestrutura

O deploy final foi executado pelo workflow serverless em
[run 34782362454](https://github.com/postech-software-architecture/workshop-auth-serverless/actions/runs/34782362454),
com build, testes, `terraform fmt`, `validate` e deploy verdes.

O Gateway possui stage `prod`; sua URL pública não é apresentada como contrato permanente.
O deploy usa um artefato versionado da Lambda, publica versão e atualiza o alias `prod`.
Os logs de acesso do Gateway não registram body, CPF ou token; Terraform não publica secrets
nos outputs.

## G4 — resultados registrados

| Cenário | Resultado observado |
|---|---:|
| CPF inválido de sequência repetida | `422`, sem acesso ao banco |
| CPF válido não elegível/inexistente | `401` genérico |
| CPF fictício semeado | `200` com `accessToken`, `Bearer` e `expiresIn=3600` |
| Token emitido | HS256; issuer, audience e claims contratuais presentes |
| `GET /api/v1/ordens-servico/minhas` sem token | `401` |
| Mesma rota com token da Lambda | `200` |
| Rota administrativa com token `CLIENTE` | `403` |
| Acesso externo ao DNS do NLB | falhou como esperado |

O teste de correlação usou o identificador não sensível `w4-g4-final-002`. Ele foi devolvido
pela Lambda e pela aplicação no header `X-Correlation-ID`; no CloudWatch, o log group
`/aws/lambda/workshop-auth-cpf` registrou o evento JSON da Lambda com o mesmo valor. A
aplicação mantém esse campo no MDC e no encoder JSON de logs.

## Observações de segurança e operação

- Nenhum token, CPF completo, senha ou segredo JWT foi registrado como evidência.
- A Lambda só emite access token; refresh e logout permanecem no fluxo legado.
- Não há Lambda Authorizer nem RDS Proxy nesta onda, conforme ADRs vigentes.
- A visibilidade de dashboards e alertas é trabalho da W5; o log da Lambda e a propagação
  de correlação são pré-requisitos já comprovados, não substitutos dessa onda.

---

**Última atualização:** 2026-09-13 · G4 aprovado na AWS Academy.
