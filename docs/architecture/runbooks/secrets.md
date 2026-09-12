# Runbook — Secrets e credenciais

**Estado documentado da configuracao:** o inventario alvo tem 17 entradas de secrets no Environment
`prod`. Credenciais AWS sao valores operacionais temporarios, renovados no inicio de
cada janela; `AWS_CREDENTIALS_READY` continua sendo a trava do plan automatico.
Execucoes anteriores nao provam que os valores ainda estejam validos nem que a
infraestrutura continue ativa.

## Inventario

| Secret | aplicacao | kubernetes | database | serverless | Origem do valor |
|---|:--:|:--:|:--:|:--:|---|
| `AWS_ACCESS_KEY_ID` | — | sim | sim | sim | Academy → AWS Details |
| `AWS_SECRET_ACCESS_KEY` | — | sim | sim | sim | Academy → AWS Details |
| `AWS_SESSION_TOKEN` | — | sim | sim | sim | Academy → AWS Details (**temporario, ~4h**) |
| `DB_PASSWORD` | — | — | sim | sim | escolhido pelo time; igual nos dois repos |
| `JWT_SECRET` | sim | — | — | sim | **um unico valor**, novo e identico nos dois repos (32+ bytes) |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | — | sim | — | sim | New Relic US → `https://otlp.nr-data.net` |
| `OTEL_EXPORTER_OTLP_HEADERS` | — | sim | — | sim | `api-key=<New Relic ingest license key>` |

Todos em **Environment** (`prod`), nao em repo — assim herdam o gate
de aprovacao. Sao 17 entradas no total entre os 4 repos; `JWT_SECRET` conta duas vezes
porque o mesmo valor deve existir nos Environments da aplicacao e do serverless. Ambiente unico
`prod` nesta fase; `homolog` foi removido em 2026-09-08 (era espelho de `prod`).

## Duas travas contra apply acidental

1. **`vars.AWS_CREDENTIALS_READY = false`** nos 3 repos. As pipelines condicionam o job
   de `plan` a essa variavel; com `false`, o job e **pulado** (nao "sucesso falso").
2. **Placeholder invalido.** Se algo escapar da trava 1, a autenticacao falha de forma
   obvia em vez de agir com credencial parcial.

Para habilitar, DEPOIS de preencher os valores:

```bash
gh variable set AWS_CREDENTIALS_READY --repo <org>/<repo> --body true
```

## Como preencher

Nunca cole credencial em chat, issue, PR ou log. Duas vias:

**CLI** (o valor nao fica no histórico do shell se vier de arquivo):
```bash
gh secret set AWS_SESSION_TOKEN \
  --repo postech-software-architecture/workshop-infra-kubernetes \
  --env prod < token.txt
rm token.txt
```

**UI**: Settings → Environments → `prod` → Environment secrets.

Depois de preencher, valide sem revelar valores:

```bash
gh secret list --repo <org>/<repo> --env prod
gh variable get AWS_CREDENTIALS_READY --repo <org>/<repo>
```

Ative `AWS_CREDENTIALS_READY=true` apenas no inicio da janela planejada e retorne a
`false` ao final. `gh secret list` comprova os nomes e as datas de atualizacao dos
secrets, enquanto `gh variable get` comprova o valor atual da flag. Nenhum dos dois
comandos revela o conteudo dos secrets.

## Credencial do Academy expira em ~4h

E a restricao central do projeto. Consequencias praticas:

- Renovar os 3 secrets AWS **nos 3 repos** antes de cada janela de trabalho (9 valores)
- Um `apply` iniciado perto do fim da janela **falha no meio** e deixa state parcial
- O `AWS_SESSION_TOKEN` e obrigatorio: credencial do Academy nao funciona sem ele

## O `JWT_SECRET` tem uma armadilha

A Lambda e a aplicacao **assinam o mesmo token**. Se os segredos divergirem, a app
rejeita o token da Lambda com `401` e o sintoma parece erro de autenticacao, nao de
configuracao.

Alem disso, o valor default commitado em `application.yml:31` do repo da aplicacao
esta no historico git de um repo **publico** (commit `118e4b3`). Trate-o como
permanentemente comprometido: o `JWT_SECRET` real precisa ser **novo**, nunca aquele.

Ver [ADR-004](../adr/ADR-004-jwt-contract.md). A rotacao e o provisionamento simultaneo nos
dois repos fazem parte da janela da W4; ate la, o contrato esta fechado, mas o valor real nao
e considerado provisionado.

## Rotacao

| Secret | Quando |
|---|---|
| AWS (3) | a cada sessao do Academy (~4h) |
| `JWT_SECRET` | na janela da W4, simultaneamente na aplicacao e no serverless; depois se houver suspeita |
| `DB_PASSWORD` | ao trocar a senha do RDS; `lifecycle.ignore_changes` evita recriar a instancia |
| New Relic ingest license key | se a chave vazar |
