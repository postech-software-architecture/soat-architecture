# ADR-001 — AWS Academy e LabRole para Lambda

**Estado:** aceito em 2026-09-09

## Decisao

Usar AWS Academy em `us-east-1` e reutilizar a role existente `LabRole` como
execution role das funcoes Lambda. Nao criar roles IAM adicionais.

## Evidencia

O [workflow 34425749565](https://github.com/postech-software-architecture/workshop-auth-serverless/actions/runs/34425749565)
criou uma Lambda Python temporaria com a `LabRole`, aguardou o estado ativo,
invocou a funcao e recebeu HTTP 200. Ao final, nenhuma funcao com prefixo
`w0-labrole-spike-` permaneceu listada no console.

## Consequencias

- A W4-A pode implementar a Lambda diretamente com a `LabRole`.
- As credenciais continuam temporarias e incluem obrigatoriamente
  `AWS_SESSION_TOKEN`.
- Toda automacao que criar recursos temporarios deve executar e conferir cleanup.
