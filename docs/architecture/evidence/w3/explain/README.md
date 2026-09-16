# W3 — checkpoint de `EXPLAIN (ANALYZE, BUFFERS)`

Fecha a divida quantitativa aberta em
[`database/performance-review.md`](../../../database/performance-review.md). Ate aqui a
revisao de indices da W3 era estrutural: as quatro FKs e os dois indices novos existiam,
mas nenhum numero de tempo, custo ou buffers tinha sido medido.

**Coletado em:** 2026-09-14

## Ambiente da medicao

| Item | Valor |
|---|---|
| Motor | PostgreSQL 15.18 (aarch64-unknown-linux-musl, Alpine) |
| Origem | container local descartavel (`compose.yaml`, servico `postgres`) |
| Migrations | 20 de 20 aplicadas, incluindo `V0.20260912185705__add_integrity_constraints_to_workshop` |
| Massa | gerada por [`seed-massa.sql`](seed-massa.sql), deterministica (`setseed(0.42)`, ancora `2026-09-14`) |
| Estatisticas | `ANALYZE` executado em todas as tabelas envolvidas antes das medicoes |

A medicao **nao** foi feita no RDS. O `DROP INDEX` exigido pela comparacao adquire lock e
nunca deve tocar a instancia ativa; o proprio `performance-review.md` proibe isso. Por ser
base descartavel, os `DROP INDEX` e o `CREATE INDEX` candidato rodaram dentro de
transacoes com `ROLLBACK`, e a presenca dos indices foi reconferida no fim.

### Massa carregada

| Tabela | Linhas |
|---|---:|
| `ordens_servico` | 200.000 |
| `ordens_servico_itens` | 600.000 |
| `historico_status_os` | 800.000 |
| `pecas_insumos` | 2.006 |
| `veiculos` | 2.003 |
| `usuarios` | 205 |

O seed das migrations traz 6 pecas e 5 usuarios. Nessa cardinalidade um filtro por
`peca_insumo_id` devolve cerca de um sexto da tabela e o planner escolhe sequential scan
com razao — o indice nao seria exercitado e a comparacao nao mediria nada. Por isso o
catalogo e o quadro de usuarios foram elevados a uma faixa de oficina real antes de medir.

### Parametros usados

| Parametro | Valor | Linhas correspondentes |
|---|---|---:|
| `peca_id` | `008865f0-b027-4138-888f-657b4ef41a1d` | 240 de 600.000 (0,04%) |
| `usuario_id` | `0803e09e-e8c7-47a1-b112-1ac3845b6e5c` | 3.903 de 800.000 (0,49%) |

## Resultado

| Consulta | Linhas da tabela | Plano sem indice | Plano com indice | Tempo antes/depois | Buffers antes/depois | Veredicto |
|---|---:|---|---|---|---|---|
| itens por `peca_insumo_id` | 600.000 | `Gather` → `Parallel Seq Scan` | `Bitmap Heap Scan` ← `Bitmap Index Scan [ix_ordens_servico_itens_peca_insumo]` | 24,028 ms → 0,253 ms (**95x**) | 8.805 → 243 blocos (**36x menos**) | indice novo da W3 justificado |
| historico por `usuario_id` | 800.000 | `Gather Merge` → `Sort` → `Parallel Seq Scan` | `Sort` ← `Index Scan [ix_historico_status_os_usuario]` | 43,926 ms → 1,106 ms (**40x**) | 16.255 → 89 blocos (**183x menos**) | indice novo da W3 justificado |
| volume diario | 200.000 | `Seq Scan` com filtro (estado atual) | `Index Only Scan [ix_os_data_criacao_status_ativas]` (candidato) | 25,510 ms → 5,269 ms (**4,8x**) | 3.514 → 37 blocos (**95x menos**) | criar o indice parcial candidato |
| tempo por etapa | 800.000 | n/a (nao ha variante sem indice) | `Index Scan [ix_historico_status_os_ordem_data]` → `WindowAgg` | 791,848 ms | 804.570 blocos | indice existente validado |

Arquivos: os planos completos em JSON estao neste diretorio, numerados de `01` a `07`.

## Leitura dos numeros

**Os dois indices novos da W3 se pagam.** Nas duas consultas que eles atendem, o ganho nao
e marginal: 95x e 40x em tempo. O numero mais solido e o de blocos, porque independe de
cache: a consulta de itens passa de 8.805 para 243 blocos tocados, e a de historico de
16.255 para 89. Isso confirma a premissa estrutural de que o PostgreSQL nao cria indice no
lado filho de uma FK e que as verificacoes de exclusao/alteracao de peca e usuario
referenciados fariam varredura completa sem eles.

**Ressalva honesta sobre cache.** O aquecimento executou a variante *com* indice antes de
medir, e essa variante toca poucas paginas. As execucoes sem indice aparecem com
`Shared Read Blocks` alto (8.503 e 7.100), ou seja, leram paginas frias. O tempo absoluto
das variantes sem indice esta portanto inflado por I/O. A comparacao de **blocos tocados**
nao sofre desse vies e sustenta a mesma conclusao; os multiplicadores de tempo devem ser
lidos como ordem de grandeza, nao como medida exata.

**O indice candidato do volume diario deixa de ser candidato.** O
`performance-review.md` registrava `(data_criacao, status) WHERE data_remocao IS NULL` como
hipotese sujeita a evidencia. Com 200.000 ordens e recorte de
`data_criacao >= '2026-08-15' AND data_criacao < '2026-09-14'`, o filtro devolve
31.127 linhas (15,6% da tabela) — faixa em que um sequential scan costuma vencer. Nao
venceu: o indice parcial permite `Index Only Scan`, cortando o tempo em 4,8x e os blocos em
95x, porque cobre as duas colunas projetadas e exclui de antemao as ordens removidas.
Recomendacao: criar o indice. Custo de escrita adicional e baixo, ja que o indice e parcial
e `data_criacao` e praticamente append-only.

**A consulta de tempo por etapa nao tem problema de plano.** Ela ja usa
`ix_historico_status_os_ordem_data` e evita um sort explicito na janela. Os 791 ms e os
804 mil blocos vem de ela varrer as 800.000 transicoes por completo — e o que a consulta
pede, sem recorte temporal. Se o painel 5 da W5 precisar dela com frequencia, o caminho nao
e mais um indice: e limitar a janela (`data_transicao >= :inicio`) ou materializar o
agregado. Fica registrado como observacao, nao como acao da W3.

## Reproduzir

```bash
cd workshop-service-fase1
docker-compose up -d postgres
# aplicar as 20 migrations, depois:
docker exec -i -e PGPASSWORD=$POSTGRES_PASSWORD workshop-service-fase1-postgres-1 \
  psql -v ON_ERROR_STOP=1 -U $POSTGRES_USER -d $POSTGRES_DB \
  < docs/architecture/evidence/w3/explain/seed-massa.sql
```

Os parametros `peca_id` e `usuario_id` sao escolhidos pela peca e pelo usuario com mais
ocorrencias, criterio deterministico sobre a massa deterministica. Nenhum dado pessoal,
segredo ou valor de producao aparece nos JSONs: os planos contem apenas nomes de tabela,
nomes de indice e os dois UUIDs sinteticos declarados acima.

Os **UUIDs nao reproduzem**: `gen_random_uuid()` nao e afetado por `setseed`. Tudo o que o
planner enxerga reproduz, porque o seed deriva distribuicao, datas e chaves estrangeiras de
`g % N`, nunca de `random()`. Na pratica, os UUIDs mudam e a selecao por "mais ocorrencias"
reencontra as mesmas linhas.

### Reproducao independente

Executada em 2026-09-15, em container limpo, pelo procedimento acima. Confere:

| Verificacao | Resultado |
|---|---|
| Motor | PostgreSQL 15.18 aarch64-musl, identico |
| Migrations | 20 de 20 aplicadas |
| Contagem das seis tabelas | identica |
| Linhas por parametro | 240 e 3.903, identicas |
| Linhas do recorte de volume diario | 31.127, identica |
| Node types e indices escolhidos nos 7 planos | identicos |
| Blocos tocados | identicos ou dentro de 3 blocos (variacao de cache) |

A reproducao corrigiu dois numeros de bloco transcritos errado na primeira coleta:
a consulta de historico toca 89 blocos, nao 118, e a de volume diario com o indice
candidato toca 37, nao 78. Os dois erros subestimavam o ganho; os JSONs sempre trouxeram
os valores certos e as conclusoes nao mudam.
