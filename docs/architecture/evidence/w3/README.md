# Evidencias da W3 — dados e contrato

**Estado:** em execucao

**Gate G3:** ainda nao satisfeito

Esta pagina separa artefatos verificaveis localmente das evidencias que exigem uma janela
AWS. Um commit preparado em worktree nao equivale a PR mergeado, pipeline verde ou recurso
implantado.

## Artefatos inspecionados localmente

| Entrega | Evidencia | Estado |
|---|---|---|
| Safety CD da aplicacao | commit `e9bb066` de `workshop-service-fase1`, exigindo deploy manual durante a W3 | preparado; CI/merge pendentes e pre-requisito dos merges de migration/OpenAPI |
| Quatro FKs com `ON DELETE RESTRICT` e identidade tecnica `system.webhook` | commit final `f62898b`, precedido por `56e56d2`, de `workshop-service-fase1` | preparado; CI/merge pendentes |
| Quatro indices das FKs novas (dois existentes + dois novos) e dois indices de FKs antigas | mesma migration; inventario em [relationships.md](../../database/relationships.md) | seis preparados para inspecao; CI pendente |
| Teste de migrations, seed, FKs, orfaos, exclusao e indices | `DatabaseIntegrityMigrationIT`, commit final `f62898b`, precedido por `56e56d2` | teste preparado para verificar; resultado de CI pendente |
| OpenAPI 3.1 como unica fonte canônica de runtime na raiz | commit final `16cbb7a`, precedido por `1602856`; copia em `src/.../controllers/` removida | preparada; CI/merge pendentes |
| Rota publica de status usa `{numero}` | `/api/v1/ordens-servico/{numero}/status` na OpenAPI raiz | conferido no artefato |
| Terraform do RDS privado, state separado e workflows seguros | commit final `3d7afd9`, precedido por `1971b71`, `02a1a5c` e `efb60fd`, de `workshop-infra-database` | preparado; CI/merge/plan/apply pendentes |
| `db_client_sg_id` associado aos nodes EKS e gates seguros | commit final `97fd209`, precedido por `2130563` e `9e4cffd`, de `workshop-infra-kubernetes` | preparado; CI/merge/plan pendentes |
| ER, escolha do banco, relacionamentos e plano de performance | documentos desta branch | preparados; render SVG/PNG pendente |

Nao existe resultado verde registrado para `DatabaseIntegrityMigrationIT`. O teste esta
preparado para verificar PostgreSQL 15, todas as migrations, seed, identidade tecnica,
quatro FKs novas, orfaos, `ON DELETE RESTRICT` e os seis indices inspecionados; somente a CI
futura pode promover esse item a evidencia.

A unica fonte canônica de runtime sera
[`/openapi.yaml`](https://github.com/postech-software-architecture/workshop-service-fase1/blob/main/openapi.yaml)
depois do merge do trilho OpenAPI. O gate exige que a copia
`src/main/java/com/postech/workshop_service/api/controllers/openapi.yaml` esteja ausente e
que build, publicacao e consumidores usem somente o arquivo da raiz. Versoes encontradas
apenas no historico Git ou em registros historicos de documentacao nao sao especificacoes
publicadas e nao contam como uma segunda fonte de runtime.

O ER em Mermaid representa 16 das 17 tabelas. `webhook_eventos_processados` foi excluida do
diagrama por nao possuir relacionamentos; gerar e revisar as renderizacoes SVG/PNG continua
pendente.

## Pendente de CI e merge

- executar e aprovar a pipeline e o merge do safety CD `e9bb066` **antes** de integrar os
  trilhos de migration e OpenAPI no mesmo repositorio;
- depois desse pre-requisito, executar e aprovar as pipelines dos trilhos de migration,
  OpenAPI, banco e acesso do cluster (`f62898b`, `16cbb7a`, `3d7afd9` e `97fd209`);
- confirmar que a suite `DatabaseIntegrityMigrationIT` passa em PostgreSQL 15;
- validar a OpenAPI raiz com parser 3.1, conferir que a copia de `src` esta ausente e que
  nenhuma spec historica e publicada como fonte de runtime;
- revisar o `terraform plan` do banco e provar que seu state nao contem VPC, EKS ou node
  group;
- revisar o `terraform plan` do cluster para a associacao de `db_client_sg_id` aos nodes.

## Pendente do checkpoint AWS

1. renovar as credenciais temporarias do AWS Academy;
2. inventariar individualmente `workshop-db`, `workshop-db-subnets` e `workshop-db-sg`;
3. subir primeiro rede/EKS e obter o contrato de outputs;
4. executar plan/apply do RDS e provar `publicly_accessible = false`, criptografia e ingress
   5432 apenas de `db_client_sg_id`;
5. iniciar a aplicacao, aplicar Flyway e comprovar conectividade a partir do EKS;
6. coletar `EXPLAIN (ANALYZE, BUFFERS)` com massa representativa conforme
   [performance-review.md](../../database/performance-review.md);
7. preservar logs, planos e identificadores de runs;
8. destruir **primeiro o RDS**, pelo workflow de `workshop-infra-database`, e confirmar sua
   remocao; somente depois destruir cluster/VPC por `workshop-infra-kubernetes`.

## Checklist do Gate G3

| Criterio | Estado |
|---|---|
| ER corresponde ao schema pos-FK | fonte 16/17 preparada; SVG/PNG e validacao pendentes |
| Quatro FKs restritivas e indices validados | teste preparado para verificar; CI pendente |
| PostgreSQL/RDS justificado e privado | documentado; apply pendente |
| State do banco respeita fronteira | validacao local/plan pendentes |
| Uma fonte OpenAPI canônica de runtime na raiz | artefato preparado; CI/merge e gate de publicacao pendentes |
| Nodes possuem `db_client_sg_id` | mudanca preparada; CI/merge/plan pendentes |
| `EXPLAIN` real antes/depois | **pendente do checkpoint** |
| Aplicacao conecta ao RDS e Flyway conclui | **pendente do checkpoint** |

O G3 so pode ser marcado como concluido quando todos os itens acima tiverem evidencia real.
