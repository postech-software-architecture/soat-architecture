# Assets New Relic da W5

Este diretório contém a configuração declarativa e reexecutável da observabilidade
operacional da W5. O backend é o New Relic US e a instrumentação continua sendo
OpenTelemetry; nenhuma chave, URL real, CPF ou token é versionado aqui.

## Conteúdo

- `dashboards/`: exatamente seis templates de dashboards New Relic One;
- `terraform/`: provider, dashboards, política NRQL, workflow de notificações e
  monitor sintético opcional;
- `scripts/validate-assets.py`: validação estática executada em CI;
- `.github/workflows/newrelic-assets.yml`: validação em PR e apply somente manual.

Os seis dashboards são: Service Overview, Ordem de Servico Lifecycle, Ordem de
Servico Reliability, Auth Serverless, EKS Infrastructure e Dependencies and
Correlation. O contrato das métricas está em
[`w5-observability-contract.md`](../w5-observability-contract.md).

## Pré-requisitos para aplicação

1. Terraform >= 1.6;
2. uma User API key do New Relic com escopo suficiente para dashboards, alertas,
   workflows e synthetics;
3. `NEW_RELIC_ACCOUNT_ID` e `NEW_RELIC_API_KEY` configurados como secrets do
   environment `prod` do repositório;
4. o endpoint de notificação e a URL do API Gateway somente na hora do apply.

O apply é deliberadamente desabilitado por padrão para notificações e synthetics.
Para ativá-los, o operador deve selecionar os inputs do workflow manual e fornecer
os valores secretos. O monitor sintético nasce `DISABLED` para permitir aprovação
explícita do custo e da URL.

## Validação local

```bash
python3 docs/architecture/observability/newrelic/scripts/validate-assets.py
terraform -chdir=docs/architecture/observability/newrelic/terraform fmt -check -recursive
terraform -chdir=docs/architecture/observability/newrelic/terraform init -backend=false
terraform -chdir=docs/architecture/observability/newrelic/terraform validate
```

O plan deve criar seis dashboards e uma condição NRQL. O alerta consulta
`workshop.ordem_servico.processing.error.count` e abre com pelo menos três eventos
em cinco minutos. A recuperação é automática quando a série fica abaixo do limite
na avaliação seguinte; a transição de recuperação deve ser registrada no G5.

## Operação e G5

O workflow não executa apply em push ou pull request. Para aplicar, use
`Actions -> New Relic W5 assets -> Run workflow`, selecione o environment `prod` e
digite literalmente `APLICAR NEW RELIC W5`. O workflow executa `sts`? Não: nenhuma
credencial AWS é necessária para estes assets; ele autentica exclusivamente no New
Relic e nunca imprime a API key.

Após o apply, registrar no evidence da W5:

- IDs dos seis dashboards e URL sanitizada;
- plan/apply sem valores sensíveis;
- alerta aberto após três falhas em cinco minutos;
- notificação recebida e recuperação observada;
- consulta correlacionando `trace.id` entre Lambda e aplicação;
- resultado do monitor sintético, se habilitado.

O apply real e os dados de produção permanecem fora deste PR.
