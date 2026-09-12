# Revisao de performance do banco

## Estado da evidencia

A revisao estrutural abaixo foi feita sobre as migrations e consultas da aplicacao. Os
resultados numericos de `EXPLAIN (ANALYZE, BUFFERS)` **ainda nao foram coletados**: eles
dependem do checkpoint com PostgreSQL executando, migrations aplicadas e volume
representativo. Nenhum tempo, custo ou quantidade de buffers e apresentado como resultado
real nesta versao.

## Indices da W3

A migration de integridade reutiliza quatro indices ja existentes e acrescenta dois:

| FK | Indice | Estado |
|---|---|---|
| `ordens_servico.id_cliente` | `ix_ordens_servico_cliente` | existente |
| `ordens_servico.id_veiculo` | `ix_ordens_servico_veiculo` | existente |
| `ordens_servico_itens.peca_insumo_id` | `ix_ordens_servico_itens_peca_insumo` | novo na W3 |
| `historico_status_os.usuario_id` | `ix_historico_status_os_usuario` | novo na W3 |

As FKs nao criam automaticamente indices no lado filho no PostgreSQL. Os dois indices novos
reduzem o custo esperado de joins, consultas por pai e verificacoes ao excluir/alterar uma
peca ou usuario referenciado. O ganho real so pode ser afirmado apos o checkpoint abaixo.

## Consultas escolhidas

### 1. Itens que usam uma peca ou insumo

```sql
SELECT i.id, i.ordem_servico_id, i.ordem_item, i.tipo
FROM ordens_servico_itens AS i
WHERE i.peca_insumo_id = :'peca_id';
```

Valida `ix_ordens_servico_itens_peca_insumo`. E relevante para rastreabilidade de catalogo,
reserva de estoque e avaliacao do impacto antes de desativar um item.

### 2. Transicoes realizadas por usuario

```sql
SELECT h.ordem_servico_id, h.status_anterior, h.status_novo, h.data_transicao
FROM historico_status_os AS h
WHERE h.usuario_id = :'usuario_id'
ORDER BY h.data_transicao DESC;
```

Valida `ix_historico_status_os_usuario`. Se o volume e o padrao de ordenacao justificarem,
um indice composto `(usuario_id, data_transicao DESC)` pode substituir o indice simples;
essa mudanca nao deve ser feita sem evidencia.

### 3. Volume diario de ordens por status

```sql
SELECT date_trunc('day', os.data_criacao) AS dia, os.status, count(*) AS total
FROM ordens_servico AS os
WHERE os.data_criacao >= :'inicio'::timestamp
  AND os.data_criacao < :'fim'::timestamp
  AND os.data_remocao IS NULL
GROUP BY 1, 2
ORDER BY 1, 2;
```

Esta e a base correta para o painel de volume diario. O indice atual apenas em `status` pode
nao ajudar no recorte temporal. Um indice parcial em `(data_criacao, status) WHERE
data_remocao IS NULL` e **candidato**, nao decisao, sujeito a `EXPLAIN` e volume real.

### 4. Tempo medio por etapa do processo

```sql
WITH etapas AS (
    SELECT ordem_servico_id,
           status_novo AS etapa,
           data_transicao AS inicio,
           lead(data_transicao) OVER (
               PARTITION BY ordem_servico_id ORDER BY data_transicao
           ) AS fim
    FROM historico_status_os
    WHERE data_remocao IS NULL
)
SELECT etapa,
       count(*) FILTER (WHERE fim IS NOT NULL) AS transicoes_concluidas,
       avg(fim - inicio) FILTER (WHERE fim IS NOT NULL) AS tempo_medio
FROM etapas
GROUP BY etapa
ORDER BY etapa;
```

Tempo por etapa vem das transicoes persistidas em `historico_status_os`. Latencia HTTP e os
campos `data_inicio_execucao`/`data_finalizacao` medem outras coisas e nao podem ser
apresentados como duracao de cada status. O indice existente
`(ordem_servico_id, data_transicao)` apoia a janela por OS.

## Checkpoint reproduzivel

Executar em uma base descartavel ou no RDS de demonstracao, depois de aplicar todas as
migrations e carregar uma massa representativa. Substituir os parametros por IDs presentes.

```sql
ANALYZE ordens_servico_itens;
ANALYZE historico_status_os;
ANALYZE ordens_servico;

EXPLAIN (ANALYZE, BUFFERS, WAL, FORMAT JSON)
SELECT id, ordem_servico_id, ordem_item, tipo
FROM ordens_servico_itens
WHERE peca_insumo_id = :'peca_id';

EXPLAIN (ANALYZE, BUFFERS, WAL, FORMAT JSON)
SELECT ordem_servico_id, status_anterior, status_novo, data_transicao
FROM historico_status_os
WHERE usuario_id = :'usuario_id'
ORDER BY data_transicao DESC;
```

Para comparar os dois indices novos sem alterar persistentemente o ambiente:

```sql
BEGIN;
DROP INDEX ix_ordens_servico_itens_peca_insumo;
EXPLAIN (ANALYZE, BUFFERS, WAL, FORMAT JSON)
SELECT id FROM ordens_servico_itens WHERE peca_insumo_id = :'peca_id';
ROLLBACK;

BEGIN;
DROP INDEX ix_historico_status_os_usuario;
EXPLAIN (ANALYZE, BUFFERS, WAL, FORMAT JSON)
SELECT ordem_servico_id FROM historico_status_os WHERE usuario_id = :'usuario_id';
ROLLBACK;
```

Depois dos `ROLLBACK`, executar novamente os planos com os indices presentes. Guardar os
quatro JSONs em `evidence/w3/explain/`, registrando versao do PostgreSQL, quantidade de
linhas por tabela e se o cache estava aquecido.

## Template de resultado pendente

| Consulta | Linhas da tabela | Plano sem indice | Plano com indice | Tempo antes/depois | Buffers antes/depois | Veredicto |
|---|---:|---|---|---|---|---|
| itens por `peca_insumo_id` | pendente | pendente | pendente | pendente | pendente | checkpoint W3 |
| historico por `usuario_id` | pendente | pendente | pendente | pendente | pendente | checkpoint W3 |
| volume diario | pendente | pendente | pendente | pendente | pendente | decidir indice candidato |
| tempo por etapa | pendente | pendente | pendente | pendente | pendente | validar indice existente |

## Riscos de volume e cardinalidade

- `historico_status_os` e `movimentacoes_estoque` crescem continuamente; retencao e
  particionamento devem ser avaliados com volume de producao, nao na amostra academica;
- indices em colunas booleanas isoladas tendem a baixa seletividade;
- indices adicionais aceleram leitura, mas aumentam escrita, armazenamento e manutencao;
- dados de seed sao adequados para integridade funcional, mas insuficientes para comparar
  planos. A evidencia final precisa informar a massa usada.
