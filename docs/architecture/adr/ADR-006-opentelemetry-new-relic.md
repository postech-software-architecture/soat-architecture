# ADR-006 — OpenTelemetry com New Relic

**Estado:** aceito em 2026-09-09

## Decisao

Usar OpenTelemetry como camada vendor-neutral de instrumentacao e exportar traces,
metricas e logs para o endpoint OTLP do New Relic US. Evitar acoplamento da aplicacao
a APIs proprietarias quando houver suporte OTLP equivalente.

## Evidencia

O [workflow 34426760765](https://github.com/postech-software-architecture/workshop-auth-serverless/actions/runs/34426760765)
enviou um trace OTLP/HTTP e recebeu HTTP 200. A consulta posterior no New Relic
retornou o span `workshop-w0-otlp-spike`, ambiente `prod`, status `OK` e
`trace.id = 4dc385e84004ef41d95a3f3e8917b336`.

## Configuracao

- `OTEL_EXPORTER_OTLP_ENDPOINT=https://otlp.nr-data.net`;
- `OTEL_EXPORTER_OTLP_HEADERS=api-key=<ingest-license-key>`;
- chaves armazenadas somente como Environment secrets.

## Consequencias

- A W5 deve construir dashboards e alertas no New Relic.
- A aplicacao, Lambda e collector devem preservar `trace.id` entre os sinais.
- Uma troca futura de backend exige alterar o exporter, nao a instrumentacao.
