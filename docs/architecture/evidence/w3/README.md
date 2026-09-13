# W3 — dados + contrato · progresso

Estado da onda apos a sessao de validacao local de 2026-09-12. Tudo que podia ser
provado sem abrir janela AWS foi executado e verificado; o que resta depende de
credenciais do Academy e esta isolado na secao final.

**Situacao:** as quatro frentes estao implementadas e com CI verde. A onda esta
**pronta para a janela AWS**, ainda nao concluida.

---

## 1. Quadro das frentes

| # | Frente | Estado | Prova |
|---|---|---|---|
| 1 | 4 FKs + indices, validadas em base vazia | **pronta** | `DatabaseIntegrityMigrationIT` (5 testes) + suite completa verde |
| 2 | OpenAPI canonica unica | **pronta** | duplicata removida; 63 operacoes conferidas contra os controllers |
| 3 | Terraform do RDS por criacao nova | **pronta** | `validate` OK; gates de inventario e plan exercitados |
| 4 | Documentacao de dados (ER, PostgreSQL, relacionamentos, performance) | **pronta** | [modelo-de-dados.md](../../data/modelo-de-dados.md), extraido do schema real |

### Pull requests

| Repo | PR | Branch | CI |
|---|---|---|---|
| `workshop-service-fase1` | [#67](https://github.com/postech-software-architecture/workshop-service-fase1/pull/67) | `feat/w3-database-integrity` | verde *(estava vermelha; ver §3)* |
| `workshop-service-fase1` | [#68](https://github.com/postech-software-architecture/workshop-service-fase1/pull/68) | `docs/w3-openapi-canonical` | verde |
| `workshop-service-fase1` | [#66](https://github.com/postech-software-architecture/workshop-service-fase1/pull/66) | `fix/w3-disable-auto-deploy` | verde |
| `workshop-infra-database` | [#3](https://github.com/postech-software-architecture/workshop-infra-database/pull/3) | `feat/w3-database-infrastructure` | verde · aguarda review |
| `workshop-infra-kubernetes` | [#6](https://github.com/postech-software-architecture/workshop-infra-kubernetes/pull/6) | `feat/w3-cluster-db-access` | verde · aguarda review |

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

## 7. O que falta — depende da AWS

Nada abaixo pode avancar sem credenciais do Academy. Esta e a fronteira onde esta
sessao para.

1. Revisar e mergear as 5 PRs (as duas de infraestrutura exigem aprovacao humana).
2. Abrir a janela AWS e subir VPC/EKS pelo `workshop-infra-kubernetes`.
3. Rodar o inventario read-only e confirmar `CREATE` antes do primeiro apply do banco.
4. Aplicar o RDS, executar Flyway contra a instancia real e validar a conexao da
   aplicacao pelo `db_client_sg`.
5. Coletar evidencias da janela (plan, apply, saida do Flyway, teste de conectividade).
6. Destruir na ordem correta: banco antes do cluster — o gate de destroy do cluster
   recusa rodar enquanto o SG do banco existir.

Riscos que permanecem abertos, herdados do ESTADO.md: o segredo JWT historico deve ser
regerado na janela da W4 e nunca reutilizado; os required status checks definitivos
ficam para a W6, quando os nomes dos jobs estabilizarem.

---

**Ultima atualizacao:** 2026-09-12 · validacao local sem acesso a AWS.
