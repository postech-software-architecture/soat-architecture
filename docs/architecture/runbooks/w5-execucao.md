# Runbook — execucao da W5

Roteiro para gerar telemetria real, disparar o alerta controlado e coletar as
evidencias do G5. Executar com o ambiente ja provisionado, na ordem abaixo.

Os comandos usam rotas e payloads **verificados contra a aplicacao** em
2026-09-14. Atencao a duas divergencias comuns:

- login fica em `/api/auth/login`, nao em `/api/v1/auth/login`;
- a criacao de OS usa `clienteDocumento` e `veiculoPlaca`, nao IDs.

## 0. Pre-requisitos

| Item | Como conferir |
|---|---|
| EKS, RDS, Lambda e assets aplicados | os quatro workflows verdes |
| Ingest key da conta correta | `curl` ao OTLP deve responder 200 (ver secao 5) |
| Dashboards e alerta criados | visiveis na conta New Relic do grupo |
| `notification_enabled=true` no apply dos assets | sem isso o G5 fica sem prova de notificacao |

Espere de 5 a 10 minutos apos os deploys antes de gerar carga: o collector
NRDOT e a Lambda levam esse tempo para estabilizar o primeiro envio.

Defina as variaveis de trabalho:

```bash
export API=https://<api-gateway-url>          # saida do workflow serverless
export APP=https://<endpoint-da-aplicacao>    # NLB interno via API Gateway
export CID=w5-g5-final-001                    # identificador nao sensivel
```

## 1. Autenticacao por CPF na Lambda

```bash
curl -s -X POST "$API/api/auth/cpf" \
  -H 'content-type: application/json' \
  -H "X-Correlation-ID: $CID" \
  --data '{"cpf":"<cpf-de-cliente-existente>"}'
```

Esperado: HTTP 200 com `accessToken` e `expiresIn=3600`. Guarde o token.

Um CPF invalido (`11111111111`) devolve 422 — e o mesmo cenario do smoke da
pipeline, util para gerar uma falha de autenticacao no dashboard 6.

## 2. Consulta autenticada na aplicacao

```bash
curl -s "$APP/api/v1/ordens-servico/minhas" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Correlation-ID: $CID"
```

Isso produz o trace HTTP com span JDBC exigido pelo G5, e liga o mesmo
`correlationId` entre Lambda e aplicacao.

## 3. Fluxo de ordem de servico

Usuarios de demonstracao (seed `V0.20260507210000`), senha `password`:
`admin.demo`, `atendente.demo`, `mecanico.demo`.

```bash
TOKEN=$(curl -s -X POST "$APP/api/auth/login" \
  -H 'content-type: application/json' \
  --data '{"username":"atendente.demo","password":"password"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["accessToken"])')

OS=$(curl -s -X POST "$APP/api/v1/ordens-servico" \
  -H "Authorization: Bearer $TOKEN" -H 'content-type: application/json' \
  -H "X-Correlation-ID: $CID" \
  --data '{"clienteDocumento":"11222333000181","veiculoPlaca":"FRT5A42",
           "descricaoProblema":"Geracao de telemetria W5"}')

ID=$(echo "$OS" | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
```

Avance o status com `mecanico.demo` para alimentar
`workshop.ordem_servico.status.duration`:

```bash
curl -s -X PATCH "$APP/api/v1/ordens-servico/$ID/iniciar-diagnostico" \
  -H "Authorization: Bearer $MEC_TOKEN" -H "X-Correlation-ID: $CID"
```

## 4. Alerta controlado

A condicao abre incidente com **tres ou mais** ocorrencias de
`workshop.ordem_servico.processing.error.count` em **cinco minutos**.

O caminho mais direto e uma transicao invalida repetida. Numa OS em
`RECEBIDO`, `iniciar-execucao` e invalido e devolve 422:

```bash
for i in 1 2 3; do
  curl -s -o /dev/null -w "tentativa $i -> HTTP %{http_code}\n" \
    -X PATCH "$APP/api/v1/ordens-servico/$ID/iniciar-execucao" \
    -H "Authorization: Bearer $MEC_TOKEN" -H "X-Correlation-ID: w5-err-$i"
done
```

As tres devem devolver **422**. Verificado em ambiente local: o contador sobe
para exatamente 3, com as tags `stage=execucao`, `operation=iniciar`,
`outcome=error` e `environment`.

**Tres erros de uma vez nao abrem o incidente.** A condicao usa
`thresholdOccurrences: ALL`, entao exige tres ou mais em **cada** janela de um
minuto dentro dos cinco, e nao o total do periodo. Disparando as tres chamadas
em sequencia, a serie fica assim e a condicao nunca se satisfaz:

```
minuto 1: 0   minuto 2: 0   minuto 3: 0   minuto 4: 3   minuto 5: 0
```

Para abrir o incidente, sustente o erro ao longo da janela — por exemplo quatro
chamadas por minuto durante sete minutos, repetindo a mesma transicao invalida
sobre a mesma ordem. Depois de confirmar a abertura e a notificacao, pare de
gerar erros e aguarde a janela seguinte para a recuperacao.

Dois detalhes que evitam falso negativo:

- o incremento **nao** passa por `afterCommit`, de proposito, porque o caminho
  de erro faz rollback e o sinal do alerta se perderia;
- uma OS inexistente devolve 404 e **nao** incrementa a metrica — o
  `RecursoNaoEncontradoException` e lancado fora do bloco contado.

No New Relic, em sequencia: confirme o incidente aberto, confirme a
notificacao no destino configurado, pare de gerar erros, e aguarde a janela
seguinte para confirmar a recuperacao.

## 5. Conferencias rapidas

```bash
# a ingest key responde?
curl -s -o /dev/null -w "%{http_code}\n" -X POST https://otlp.nr-data.net:4318/v1/metrics \
  -H "api-key: $NEW_RELIC_LICENSE_KEY" \
  -H 'content-type: application/json' --data '{"resourceMetrics":[]}'
```

NRQL para confirmar chegada de dados:

```sql
FROM Metric SELECT count(*)
WHERE metricName LIKE 'workshop.%' SINCE 30 minutes ago FACET metricName

FROM Span SELECT count(*)
WHERE service.name IN ('workshop-service','workshop-auth-serverless')
SINCE 30 minutes ago FACET service.name

FROM Log SELECT * WHERE correlationId = 'w5-g5-final-001' SINCE 30 minutes ago
```

## 6. Evidencias do G5

Registrar em `evidence/w5/`:

1. os seis dashboards com dados reais;
2. um trace HTTP da aplicacao contendo span JDBC;
3. o mesmo `correlationId` encontrado na Lambda e na aplicacao;
4. incidente aberto;
5. notificacao recebida;
6. incidente recuperado;
7. busca demonstrando ausencia de CPF, JWT, senha e secrets nos logs;
8. URLs das Actions, stage sanitizado do API Gateway, NRQL e capturas.

Para o item 7, os termos a buscar sao o documento do cliente usado, o prefixo
`eyJ` de JWT e a senha `password`. Em ambiente local a varredura nao encontrou
nenhum dos tres.

## 7. Encerramento

Destruir na ordem inversa: serverless, depois database
(`DESTRUIR DATABASE ANTES DO CLUSTER`), depois EKS (`DESTRUIR-PROD`).

O destroy do EKS ja falhou uma vez por ENIs da Lambda ainda anexadas. Destruir
o serverless primeiro e o que evita a repeticao: o gate do EKS bloqueia
enquanto o `db_client_sg_id` estiver em uso por Lambda em VPC.
