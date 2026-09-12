# ADR-005 — Backend Terraform remoto com S3 e DynamoDB

**Estado:** aceito em 2026-09-12

## Decisao

Persistir os states Terraform em um bucket S3 versionado e serializar operacoes com
lock no DynamoDB. O state do cluster usa a chave `cluster/terraform.tfstate`; banco
e serverless devem usar chaves proprias no mesmo padrao.

O bucket `soat-tc3-tfstate-mateus-paz` e a tabela `soat-tc3-tflock` vivem em
`us-east-1` e sao bootstrap externo: nao pertencem a nenhum dos states que armazenam.
Por isso continuam disponiveis depois do destroy da infraestrutura da aplicacao.

## Evidencia

O [apply inicial 34546920538](https://github.com/postech-software-architecture/workshop-infra-kubernetes/actions/runs/34546920538)
criou o cluster usando o backend remoto. O [apply 34716391300](https://github.com/postech-software-architecture/workshop-infra-kubernetes/actions/runs/34716391300)
reabriu o mesmo state em outra sessao do Academy e aplicou somente uma mudanca no
Helm release: `0 added, 1 changed, 0 destroyed`.

## Consequencias

- Os repos consumidores leem apenas os outputs necessarios via `terraform_remote_state`.
- Secrets como senha do banco e JWT nao trafegam pelo state.
- Apply e destroy usam Environment `prod`, confirmacao textual e grupo de concorrencia.
- Bucket e tabela de lock nao devem ser incluidos no destroy dos states consumidores.
- Credenciais temporarias do Academy precisam ser renovadas antes de cada janela.
