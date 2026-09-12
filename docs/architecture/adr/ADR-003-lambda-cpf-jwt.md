# ADR-003 — Lambda de autenticacao por CPF

- **Status:** aceita
- **Data:** 2026-09-12
- **Substitui:** nenhuma decisao

## Contexto

A Fase 3 exige autenticacao de cliente por CPF em uma funcao serverless. A aplicacao ja
possui usuarios, roles, validacao JWT e o endpoint protegido
`GET /api/v1/ordens-servico/minhas`. O spike da W0 comprovou que uma Lambda consegue usar a
`LabRole`; o spike de rede comprovou API Gateway -> VPC Link -> NLB interno -> EKS.

## Decisao

Implementar uma Lambda Java 21 no repositorio `workshop-auth-serverless`. Ela:

1. recebe apenas o CPF;
2. valida formato e digitos antes de consultar o banco;
3. acessa o RDS privado usando as subnets e o security group fornecidos pelo contrato de
   infraestrutura;
4. consulta cliente ativo e usuario associado;
5. emite somente access token conforme o ADR-004;
6. nao implementa RBAC: a aplicacao continua carregando o usuario e suas roles do banco.

O API Gateway e a unica borda publica. A rota de CPF aponta para a Lambda e as rotas da
aplicacao usam VPC Link e NLB interno.

## Alternativas rejeitadas

- Lambda chamar a aplicacao: mantida apenas como fallback caso a `LabRole` deixe de ser
  assumivel pela funcao.
- Expor o RDS publicamente: viola a fronteira de rede e o G3.
- Migrar autorizacao para a Lambda ou para claims: duplicaria a regra de RBAC existente.
- Retornar refresh token: o fluxo por CPF e curto; refresh/logout permanecem no login de
  funcionarios da aplicacao.

## Consequencias positivas

- autenticacao por CPF fica isolada e escalavel;
- CPF invalido nao consome conexao de banco;
- o modelo de autorizacao existente e preservado;
- cada componente possui repositorio e pipeline proprios.

## Consequencias negativas

- dois emissores precisam compartilhar contrato e segredo de assinatura;
- Lambda em VPC adiciona latencia de cold start e dependencia do RDS;
- o fallback de credencial do Academy e menos adequado que IRSA/Pod Identity de producao.

## Evidencias e links

- [ADR-002](ADR-002-api-gateway-vpc-link-nlb.md)
- [ADR-004](ADR-004-jwt-contract.md)
- [LabRole aprovada — run 34425749565](https://github.com/postech-software-architecture/workshop-auth-serverless/actions/runs/34425749565)
- [VPC Link/NLB aprovado — run 34716577120](https://github.com/postech-software-architecture/workshop-auth-serverless/actions/runs/34716577120)
