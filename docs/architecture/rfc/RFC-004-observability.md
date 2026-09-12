# RFC-004 — Estrategia de observabilidade

- **Status:** aceita
- **Autores:** Grupo SOAT
- **Data:** 2026-09-12

## Contexto

A solucao precisa correlacionar aplicacao, Lambda e infraestrutura, alem de demonstrar
metricas, logs, traces, dashboards e alertas. O grupo validou ingestao OTLP no New Relic US.

## Problema

Escolher uma plataforma de backend sem acoplar a instrumentacao da aplicacao a um
fornecedor especifico.

## Requisitos e restricoes

- OpenTelemetry como protocolo;
- logs JSON com correlation ID, trace ID e span ID;
- metricas de infraestrutura e de negocio;
- seis dashboards e alerta testado;
- free tier suficiente para a demonstracao.

## Opcoes consideradas

1. OpenTelemetry + New Relic US.
2. Agente proprietario do New Relic.
3. OpenTelemetry + Grafana Cloud.
4. Apenas CloudWatch.

## Comparacao

OTLP mantem a instrumentacao portavel. O New Relic foi validado pelo spike e oferece uma
experiencia integrada para logs, metricas e traces. O agente proprietario cria acoplamento;
Grafana Cloud exigiria repetir a validacao; CloudWatch isolado nao atende com a mesma
clareza aos dashboards e correlacao exigidos.

## Proposta aceita

Instrumentar com OpenTelemetry e usar New Relic US como backend. Exporters ficam desligados
por padrao nos testes e sao habilitados por variaveis no ambiente implantado.

## Impactos

- tokens e endpoints do New Relic permanecem em secrets;
- logs de `prod` sao JSON e ambientes locais continuam legiveis;
- dashboards, alertas e capturas serao versionados na W5;
- a decisao definitiva esta no ADR-006.

## Questoes em aberto

Definir na W5 as queries e thresholds finais a partir de trafego real.
