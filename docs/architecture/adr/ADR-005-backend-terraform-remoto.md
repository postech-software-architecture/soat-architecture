# ADR-005 — Backend Terraform remoto com S3 e DynamoDB

**Estado:** aceito em 2026-09-12

## Decisao

Persistir os states Terraform em um bucket S3 versionado e serializar operacoes com
lock no DynamoDB. Esta decisao foi implantada e comprovada para o cluster, na chave
`cluster/terraform.tfstate`. Banco e serverless adotarao chaves proprias durante as
ondas W3 e W4; esse rollout ainda nao foi executado.

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
- Secrets nao sao publicados como outputs nem consumidos via `terraform_remote_state`.
  Valores atribuídos a recursos, como `aws_db_instance.password`, podem existir no
  arquivo de state mesmo quando marcados `sensitive`; essa marca apenas oculta a CLI.
- O bucket deve permanecer privado, com Block Public Access, criptografia e acesso
  restrito aos operadores/pipelines autorizados. No Academy, a `LabRole` ampla e uma
  limitacao conhecida e reforca a proibicao de publicar ou anexar o state.
- Apply e destroy usam Environment `prod`, confirmacao textual e grupo de concorrencia.
- Bucket e tabela de lock nao devem ser incluidos no destroy dos states consumidores.
- Credenciais temporarias do Academy precisam ser renovadas antes de cada janela.
