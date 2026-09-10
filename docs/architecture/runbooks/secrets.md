# Runbook — Secrets e credenciais

**Estado documentado da configuracao:** os 18 secrets dos Environments foram criados
com placeholder e as CIs permanecem travadas por `AWS_CREDENTIALS_READY=false`.
O EKS ja foi aplicado e validado manualmente com credenciais temporarias; isso nao
significa que o cluster continue ativo nem que os secrets da CI estejam preenchidos.

## Inventario

| Secret | kubernetes | database | serverless | Origem do valor |
|---|:--:|:--:|:--:|---|
| `AWS_ACCESS_KEY_ID` | sim | sim | sim | Academy → AWS Details |
| `AWS_SECRET_ACCESS_KEY` | sim | sim | sim | Academy → AWS Details |
| `AWS_SESSION_TOKEN` | sim | sim | sim | Academy → AWS Details (**temporario, ~4h**) |
| `DB_PASSWORD` | — | sim | sim | escolhido pelo time; igual nos dois repos |
| `JWT_SECRET` | — | — | sim | **identico** ao da aplicacao (32+ bytes) |
| `GRAFANA_OTLP_ENDPOINT` | sim | — | sim | Grafana Cloud → OTLP |
| `GRAFANA_INSTANCE_ID` | sim | — | sim | Grafana Cloud → OTLP |
| `GRAFANA_API_TOKEN` | sim | — | sim | Grafana Cloud → token de ingest |

Todos em **Environment** (`prod`), nao em repo — assim herdam o gate
de aprovacao. 18 secrets no total (3 repos × 4–8 secrets). Ambiente unico
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
`false` ao final. A listagem do GitHub comprova nomes e datas, nunca o conteudo.

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

Ver ADR-004 (contrato JWT) quando existir.

## Rotacao

| Secret | Quando |
|---|---|
| AWS (3) | a cada sessao do Academy (~4h) |
| `JWT_SECRET` | uma vez, agora (o default esta exposto); depois se houver suspeita |
| `DB_PASSWORD` | ao trocar a senha do RDS; `lifecycle.ignore_changes` evita recriar a instancia |
| Grafana | se o token vazar |
