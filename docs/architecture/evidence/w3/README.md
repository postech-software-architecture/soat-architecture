# W3 — dados + contrato · evidencia de execucao

Estado da onda apos a validacao local de 2026-09-12 e a janela AWS de 2026-09-13.
Infraestrutura, banco, migrations e aplicacao foram exercitados na conta do AWS
Academy por pipelines na `main`.

**Situacao:** gate operacional da W3 concluido e dependencia da W4 liberada. A coleta
quantitativa de `EXPLAIN (ANALYZE, BUFFERS)` continua registrada como evidencia de
performance pendente, sem numeros inventados.

---

## 1. Quadro das frentes

| # | Frente | Estado | Prova |
|---|---|---|---|
| 1 | 4 FKs + indices, validadas em base vazia | **concluida** | `DatabaseIntegrityMigrationIT` (5 testes), suite completa e boot real com Flyway |
| 2 | OpenAPI canonica unica | **concluida** | duplicata removida; 63 operacoes conferidas contra os controllers |
| 3 | Terraform do RDS por criacao nova | **concluida** | plan, apply, validacao AWS e rotacao de senha executados na `main` |
| 4 | Documentacao de dados (ER, PostgreSQL, relacionamentos, performance) | **parcial** | modelo, ER e relacionamentos concluidos; medicao numerica de `EXPLAIN` pendente |

### Pull requests

| Repo | PR | Branch | CI |
|---|---|---|---|
| `workshop-service-fase1` | [#67](https://github.com/postech-software-architecture/workshop-service-fase1/pull/67) | `feat/w3-database-integrity` | **mergeada**; CI verde *(estava vermelha; ver §3)* |
| `workshop-service-fase1` | [#68](https://github.com/postech-software-architecture/workshop-service-fase1/pull/68) | `docs/w3-openapi-canonical` | **mergeada**; CI verde |
| `workshop-service-fase1` | [#66](https://github.com/postech-software-architecture/workshop-service-fase1/pull/66) | `fix/w3-disable-auto-deploy` | **mergeada**; CI verde |
| `workshop-infra-database` | [#3](https://github.com/postech-software-architecture/workshop-infra-database/pull/3) | `feat/w3-database-infrastructure` | **mergeada**; CI verde |
| `workshop-infra-database` | [#4](https://github.com/postech-software-architecture/workshop-infra-database/pull/4) | `fix/read-cluster-contract-before-plan` | **mergeada**; corrige bootstrap do primeiro plan |
| `workshop-infra-kubernetes` | [#6](https://github.com/postech-software-architecture/workshop-infra-kubernetes/pull/6) | `feat/w3-cluster-db-access` | **mergeada**; CI verde |
| `workshop-service-fase1` | [#69](https://github.com/postech-software-architecture/workshop-service-fase1/pull/69) | `fix/public-aws-load-balancer` | **mergeada**; smoke test externo liberado |

## 2. Integridade do banco

A migration `V0.20260912185705__add_integrity_constraints_to_workshop.sql` cria as
quatro FKs previstas, todas com `ON DELETE RESTRICT`, mais dois indices de suporte:

| Constraint | Origem → destino |
|---|---|
| `fk_ordens_servico_clientes` | `ordens_servico.id_cliente` → `clientes.id` |
| `fk_ordens_servico_veiculos` | `ordens_servico.id_veiculo` → `veiculos.id` |
| `fk_ordens_servico_itens_pecas_insumos` | `ordens_servico_itens.peca_insumo_id` → `pecas_insumos.id` |
| `fk_historico_status_os_usuarios` | `historico_status_os.usuario_id` → `usuarios.id` |

A migration tambem corrige um problema de dados preexistente: o historico gerado pelo
webhook de orcamento usava um UUID novo por origem, deixando linhas orfas. Ela cria a
conta tecnica `system.webhook` — nao autenticavel por construcao — e reaponta o
historico legado para ela, preservando a origem em `usuario_username`.

**Prova executada:** `mvnw verify` completo, 351 testes unitarios + 104 de integracao,
0 falhas, cobertura atendida. `DatabaseIntegrityMigrationIT` sobe PostgreSQL 15 via
Testcontainers, roda Flyway do zero sobre base vazia e confere FKs e indices — a prova
exigida pelo ESTADO.md.

## 3. Correcao aplicada nesta sessao

A PR #67 estava com **CI vermelha**: 12 testes falhando. A investigacao mostrou que as
constraints estavam corretas e que o problema eram fixtures de teste que inseriam linhas
orfas — invalidas a partir das novas FKs.

Duas causas:

- `HistoricoStatusOrdemServicoRepositoryImplIT` inseria `ordens_servico` com
  `id_cliente`/`id_veiculo` vindos de `UUID.randomUUID()`.
- `AutenticacaoTestSupport` gerava UUID aleatorio para o staff autenticado; esse id ia
  para `historico_status_os.usuario_id` sem linha em `usuarios`. Como o
  `GlobalExceptionHandler` traduz `DataAccessException` em 503, 10 casos apareciam como
  `expected:<200> but was:<503>`, escondendo a violacao de integridade.

Havia ainda um efeito de segunda ordem: o `TRUNCATE` da `PostgresTestContainer` limpa
`usuarios` e removia a conta `system.webhook` criada pela propria migration — enquanto
`WebhookOrcamentoControllerIT` afirma que o responsavel e `USUARIO_TECNICO_ID`. A conta
e **invariante do schema** a partir desta onda, e passou a ser recriada apos a limpeza.

Correcao no commit `6227e6f`, restrita a `src/test/java`; migration e FKs inalteradas.
A CI da PR ficou verde apos o push.

## 4. Contrato entre repositorios

O acoplamento entre cluster e banco e feito por um unico id, verificado nesta sessao:

- `workshop-infra-kubernetes` publica `db_client_sg_id` — um SG sem regras de ingress,
  anexado aos nodes pelo launch template, que serve apenas como identidade;
- `workshop-infra-database` autoriza **esse id** no ingress 5432, sem conhecer mais nada
  do cluster; nao ha CIDR aberto e o banco nao e publicamente acessivel.

O repo de banco nao declara nenhum recurso de VPC ou EKS — criterio do gate G3,
conferido por busca direta nos arquivos `.tf`.

Na janela real, o contrato entregou a VPC `vpc-06b5e9b7a9c84322d` e as subnets privadas
`subnet-0f0aac0ed23de948f` e `subnet-033492965a9fb78d2`. O RDS foi criado nessas
subnets, permaneceu `publicly_accessible = false` e aceitou 5432 somente pelo SG de
identidade publicado pelo cluster. Credenciais e valores sensiveis nao sao registrados.

## 5. Gates de seguranca — exercitados localmente

Os scripts que protegem a janela AWS foram testados com harness, sem tocar na nuvem.

**Inventario pre-apply** (`inventory-database.sh`) — 12 cenarios, todos corretos.
O ponto que o ESTADO.md destaca esta coberto: instancia RDS ausente **nao** libera o
apply se o subnet group ou o security group existirem; qualquer topologia parcial
aborta e exige reconciliacao. O SG e identificado pela chave natural VPC + nome, com a
tag `Project` validada depois como ownership, nunca como filtro de existencia.

**Validacao do plan** (`validate-plan.sh`) — 6 cenarios, todos corretos:

| Cenario | Resultado |
|---|---|
| plan com os tres enderecos canonicos | aceito |
| ingress `0.0.0.0/0` | bloqueado |
| regra SSH extra escondida no mesmo SG | bloqueado |
| range de portas amplo (0–65535) | bloqueado |
| recurso fora da fronteira (ex.: bucket S3) | bloqueado |
| replacement do RDS (delete + create) | bloqueado |

**Destroy do cluster** (`destroy.yml`) bloqueia derrubar a rede enquanto ENIs, security
groups ou Lambdas ainda referenciarem o `db_client_sg`, e acumula os tres diagnosticos
antes de falhar.

Verificacoes complementares: 9 workflows com YAML valido, 5 scripts sem erro de sintaxe,
`terraform fmt` e `validate` OK nos dois repos de infraestrutura.

## 6. Contrato de API

A duplicata foi eliminada: resta um unico `openapi.yaml` na raiz (o de
`api/controllers/` foi removido, −3260 linhas). Os arquivos sob `specs/` sao artefatos
historicos por feature e nao concorrem como contrato.

O spec e OpenAPI 3.1.0, com 49 paths, 63 operacoes e 57 schemas. O cruzamento
automatico entre as rotas do spec e as declaradas nos controllers nao encontrou
**nenhuma rota implementada ausente do contrato**. O endpoint publico de status usa
`{numero}`, como exigido.

## 7. Execucao na AWS Academy

| Etapa | Evidencia | Resultado |
|---|---|---|
| VPC/EKS e contrato de rede | [Apply EKS 34766159303](https://github.com/postech-software-architecture/workshop-infra-kubernetes/actions/runs/34766159303) | cluster `workshop-eks`, VPC e duas subnets privadas criados |
| Primeiro plan do banco | [Run 34767280981](https://github.com/postech-software-architecture/workshop-infra-database/actions/runs/34767280981) | falhou com seguranca antes de criar recursos; revelou leitura prematura do data source |
| Correcao do bootstrap | [PR database #4](https://github.com/postech-software-architecture/workshop-infra-database/pull/4) | outputs do cluster lidos diretamente do state S3 antes do primeiro plan |
| Plan real do RDS | [Run 34769155815](https://github.com/postech-software-architecture/workshop-infra-database/actions/runs/34769155815) | `3 add, 0 change, 0 destroy`; somente RDS, subnet group e DB SG |
| Apply e invariantes do RDS | [Run 34769425980](https://github.com/postech-software-architecture/workshop-infra-database/actions/runs/34769425980) | criacao e validacao pos-apply verdes |
| Rotacao da senha master | [Run 34770902869](https://github.com/postech-software-architecture/workshop-infra-database/actions/runs/34770902869) | update in-place e validacao pos-apply verdes; segredo sincronizado sem registrar o valor |
| Primeiro deploy da aplicacao | [Run 34771314525](https://github.com/postech-software-architecture/workshop-service-fase1/actions/runs/34771314525) | duas replicas prontas; revelou Load Balancer no esquema interno padrao |
| Correcao da exposicao de teste | [PR aplicacao #69](https://github.com/postech-software-architecture/workshop-service-fase1/pull/69) | Service declarou `internet-facing` e ganhou gate de CI |
| Deploy final e smoke test | [Run 34772090064](https://github.com/postech-software-architecture/workshop-service-fase1/actions/runs/34772090064) | rollout verde; readiness publico respondeu HTTP 200 |

O endpoint observado foi
`k8s-workshop-workshop-e971a01c36-299e3afd7e4c1602.elb.us-east-1.amazonaws.com`.
O DNS resolveu para endereco publico e `GET /actuator/health/readiness` respondeu 200.
Esse DNS e efemero e serve como evidencia da janela, nao como contrato permanente.

O Flyway executa antes de a aplicacao concluir o startup. Portanto, as duas replicas
`Ready` comprovam que o schema real foi migrado e que os pods alcancaram o RDS privado.
O workflow atual nao captura a saida detalhada do Flyway: essa e uma inferencia
operacional identificada, nao um log bruto de migration.

## 8. Correcoes reveladas pela execucao real

O primeiro plan do database falhou porque `terraform console` avalia apenas o state
atual. Antes do primeiro plan, o data source `terraform_remote_state` ainda aparecia
como `(known after apply)`, embora o state do cluster ja contivesse uma VPC valida. A
PR #4 removeu esse impasse sem relaxar os gates de seguranca.

O primeiro deploy ficou saudavel dentro do cluster, mas o AWS Load Balancer Controller
adotou seu esquema padrao interno. A PR #69 tornou a exposicao de smoke test
explicitamente `internet-facing`; o segundo deploy produziu um novo ELB e permitiu a
validacao externa. Na W4, a borda oficial continua sendo API Gateway + VPC Link/NLB
interno; o acesso direto temporario nao deve ser apresentado como topologia final.

## 9. Pendencias que nao bloqueiam o inicio da W4

- coletar e versionar os JSONs de `EXPLAIN (ANALYZE, BUFFERS)` com massa declarada,
  conforme o [plano de performance](../../database/performance-review.md);
- capturar log detalhado de Flyway em uma proxima execucao se a banca exigir prova
  direta alem do readiness;
- fechar o acesso direto ao Load Balancer quando a borda privada da W4 estiver pronta;
- ao encerrar a janela, remover primeiro os workloads/ELB, depois destruir o banco e
  somente entao o cluster.

Riscos herdados: o segredo JWT historico deve ser regenerado na janela da W4 e nunca
reutilizado; os required status checks definitivos ficam para a W6.

---

**Ultima atualizacao:** 2026-09-13 · gate operacional executado na AWS Academy.
