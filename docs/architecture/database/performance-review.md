# Revisao de performance do banco

## Estado da evidencia

A revisao estrutural abaixo foi feita sobre as migrations e consultas da aplicacao. Na
janela AWS de 2026-09-13, o RDS foi criado, a aplicacao concluiu o startup/Flyway e duas
replicas ficaram `Ready`, mas os resultados numericos de `EXPLAIN (ANALYZE, BUFFERS)` nao
tinham sido coletados.

**Divida encerrada em 2026-09-14.** Os planos foram medidos em base descartavel local
(PostgreSQL 15.18, 20 de 20 migrations, massa declarada de 200.000 ordens / 600.000 itens /
800.000 transicoes) e estao em
[`evidence/w3/explain/`](../evidence/w3/explain/README.md), com os sete JSONs e o script
de massa. A medicao nao foi feita no RDS porque a comparacao exige `DROP INDEX`, proibido
na instancia ativa pela secao "Checkpoint reproduzivel" deste documento.

## Indices da W3

A migration de integridade fecha quatro FKs: reutiliza dois indices ja existentes e
acrescenta dois:

| FK | Indice | Estado |
|---|---|---|
| `ordens_servico.id_cliente` | `ix_ordens_servico_cliente` | existente |
| `ordens_servico.id_veiculo` | `ix_ordens_servico_veiculo` | existente |
| `ordens_servico_itens.peca_insumo_id` | `ix_ordens_servico_itens_peca_insumo` | novo na W3 |
| `historico_status_os.usuario_id` | `ix_historico_status_os_usuario` | novo na W3 |

O teste preparado tambem inspeciona dois indices de FKs antigas,
`ix_ordens_servico_itens_servico` e `ix_historico_status_os_ordem_data`. Portanto, sao seis
indices inspecionados no total: quatro atendem as FKs novas (dois existentes + dois novos) e
dois protegem relacionamentos preexistentes.

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

Executar as consultas com indices em uma base descartavel ou no RDS de demonstracao, depois
de aplicar todas as migrations e carregar uma massa representativa. Substituir os parametros
por IDs presentes.

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

O experimento **sem indice** abaixo usa `DROP INDEX` e so pode ser executado em uma base
descartavel, isolada e sem trafego. Ele nunca deve ser executado no RDS ativo, mesmo dentro de
transacao, pois o `DROP INDEX` adquire locks e pode afetar requisicoes concorrentes.

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

## Resultado medido

Coleta de 2026-09-14. Planos completos e ressalvas em
[`evidence/w3/explain/`](../evidence/w3/explain/README.md).

| Consulta | Linhas da tabela | Plano sem indice | Plano com indice | Tempo antes/depois | Buffers antes/depois | Veredicto |
|---|---:|---|---|---|---|---|
| itens por `peca_insumo_id` | 600.000 | `Parallel Seq Scan` | `Bitmap Index Scan [ix_ordens_servico_itens_peca_insumo]` | 24,028 ms → 0,253 ms | 8.805 → 243 blocos | indice novo justificado |
| historico por `usuario_id` | 800.000 | `Parallel Seq Scan` + `Sort` | `Index Scan [ix_historico_status_os_usuario]` | 43,926 ms → 1,106 ms | 16.255 → 89 blocos | indice novo justificado |
| volume diario | 200.000 | `Seq Scan` com filtro | `Index Only Scan` no indice parcial candidato | 25,510 ms → 5,269 ms | 3.514 → 37 blocos | **criar** o indice candidato |
| tempo por etapa | 800.000 | n/a | `Index Scan [ix_historico_status_os_ordem_data]` → `WindowAgg` | 791,848 ms | 804.570 blocos | indice existente validado |

O indice parcial `(data_criacao, status) WHERE data_remocao IS NULL`, ate aqui hipotese,
passa a ser recomendacao: mesmo devolvendo 15,6% da tabela — faixa em que sequential scan
costuma vencer — ele habilita `Index Only Scan` e corta blocos em 95x. A consulta de tempo
por etapa nao tem problema de plano; seu custo vem de varrer todas as transicoes sem
recorte temporal, e a acao correspondente pertence ao painel 5 da W5, nao a W3.

## Riscos de volume e cardinalidade

- `historico_status_os` e `movimentacoes_estoque` crescem continuamente; retencao e
  particionamento devem ser avaliados com volume de producao, nao na amostra academica;
- indices em colunas booleanas isoladas tendem a baixa seletividade;
- indices adicionais aceleram leitura, mas aumentam escrita, armazenamento e manutencao;
- dados de seed sao adequados para integridade funcional, mas insuficientes para comparar
  planos. A evidencia final precisa informar a massa usada.
