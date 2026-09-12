# RFC-002 — Estrategia de autenticacao por CPF

- **Status:** aceita
- **Autores:** Grupo SOAT
- **Data:** 2026-09-12

## Contexto

A aplicacao ja autentica funcionarios por usuario e senha e valida autorizacao consultando
o usuario no banco. A Fase 3 acrescenta autenticacao de cliente por CPF em uma funcao
serverless, sem transferir o RBAC para o API Gateway.

## Problema

Definir se a Lambda consulta diretamente o RDS ou delega a autenticacao para a aplicacao,
e como o token emitido permanece compativel com o filtro existente.

## Requisitos e restricoes

- CPF invalido deve ser rejeitado antes de acessar o banco;
- Lambda e aplicacao devem emitir tokens com o mesmo contrato;
- o RDS nao pode ser publico;
- autorizacao continua centralizada na aplicacao;
- a Lambda retorna somente access token.

## Opcoes consideradas

1. Lambda consulta o RDS em subnets privadas.
2. Lambda chama um endpoint interno da aplicacao.
3. Migrar identidade e autorizacao para um provedor externo.

## Comparacao

A consulta direta reduz acoplamento HTTP e foi viabilizada pelo spike da `LabRole`. A
delegacao para a aplicacao e o fallback caso a role deixe de ser assumivel. Um provedor
externo ampliaria o escopo e nao preservaria naturalmente o modelo de usuarios existente.

## Proposta aceita

Usar Lambda Java 21 em rede privada, validando o CPF localmente e consultando
`clientes JOIN usuarios`. O token segue o contrato do ADR-004; a aplicacao valida assinatura,
carrega o usuario e aplica RBAC.

## Impactos

- Lambda precisa do endpoint do RDS, security group e segredo compartilhado;
- mudancas no JWT exigem teste cruzado entre os dois emissores;
- API Gateway permanece como unica borda publica;
- a decisao e formalizada no ADR-003.

## Questoes em aberto

Nenhuma para iniciar a W4. Pool de conexoes e cold start serao medidos durante a integracao.
