# Evidencias da W3 — dados e contrato

**Estado:** em execucao

**Gate G3:** ainda nao satisfeito

Esta pagina separa artefatos verificaveis localmente das evidencias que exigem uma janela
AWS. Um commit preparado em worktree nao equivale a PR mergeado, pipeline verde ou recurso
implantado.

## Artefatos inspecionados localmente

| Entrega | Evidencia | Estado |
|---|---|---|
| Quatro FKs com `ON DELETE RESTRICT` | migration no commit `915d7bf` de `workshop-service-fase1` | preparada |
| Dois indices novos e quatro reutilizados | mesma migration; inventario em [relationships.md](../../database/relationships.md) | preparado |
| Teste de migrations, seed, FKs, orfaos, exclusao e indices | `DatabaseIntegrityMigrationIT`, commit `d02b1c2` | preparado; resultado de CI pendente |
| OpenAPI 3.1 unica e canônica na raiz | commit `1602856`; duplicata em `src/.../controllers/` removida | preparada |
| Rota publica de status usa `{numero}` | `/api/v1/ordens-servico/{numero}/status` na OpenAPI raiz | conferido no artefato |
| Terraform do RDS privado e state separado | commit `1971b71` de `workshop-infra-database` | preparado; apply pendente |
| ER, escolha do banco, relacionamentos e plano de performance | documentos desta branch | preparados |

Uma execucao local de `mvn -Dtest=DatabaseIntegrityMigrationIT test` em 2026-09-12 chegou a
compilar e iniciar o teste, mas foi interrompida antes das assercoes porque nao havia um
daemon Docker acessivel ao Testcontainers. Portanto, esta tentativa **nao** e registrada
como teste verde; a execucao em CI ou em uma maquina com Docker continua obrigatoria.

A especificacao canônica sera
[`/openapi.yaml`](https://github.com/postech-software-architecture/workshop-service-fase1/blob/main/openapi.yaml)
depois do merge do trilho OpenAPI. Nao deve restar outra `openapi.yaml` na aplicacao.

## Pendente de CI e merge

- executar e aprovar as pipelines dos repositorios de aplicacao e banco;
- confirmar que a suite `DatabaseIntegrityMigrationIT` passa em PostgreSQL 15;
- validar a OpenAPI com parser 3.1 e conferir que existe exatamente um arquivo;
- revisar `terraform plan` e provar que o state do banco nao contem VPC, EKS ou node group.

## Pendente do checkpoint AWS

1. renovar as credenciais temporarias do AWS Academy;
2. inventariar individualmente `workshop-db`, `workshop-db-subnets` e `workshop-db-sg`;
3. subir primeiro rede/EKS e obter o contrato de outputs;
4. executar plan/apply do RDS e provar `publicly_accessible = false`, criptografia e ingress
   5432 apenas de `db_client_sg_id`;
5. iniciar a aplicacao, aplicar Flyway e comprovar conectividade a partir do EKS;
6. coletar `EXPLAIN (ANALYZE, BUFFERS)` com massa representativa conforme
   [performance-review.md](../../database/performance-review.md);
7. preservar logs, planos e identificadores de runs antes de destruir banco e cluster.

## Checklist do Gate G3

| Criterio | Estado |
|---|---|
| ER corresponde ao schema pos-FK | preparado, sujeito ao merge/teste |
| Quatro FKs restritivas e indices validados | teste preparado; CI pendente |
| PostgreSQL/RDS justificado e privado | documentado; apply pendente |
| State do banco respeita fronteira | validacao local/plan pendentes |
| Exatamente uma OpenAPI canônica | artefato preparado; merge pendente |
| `EXPLAIN` real antes/depois | **pendente do checkpoint** |
| Aplicacao conecta ao RDS e Flyway conclui | **pendente do checkpoint** |

O G3 so pode ser marcado como concluido quando todos os itens acima tiverem evidencia real.
