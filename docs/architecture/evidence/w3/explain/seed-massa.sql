-- Massa representativa para o checkpoint de EXPLAIN da W3.
--
-- Base descartavel (PostgreSQL local em container), nunca o RDS ativo. O seed de
-- demonstracao das migrations e suficiente para integridade funcional, mas nao para
-- comparar planos: com 6 pecas e 5 usuarios qualquer filtro devolve fracao grande da
-- tabela e o planner escolhe seq scan corretamente. Este script eleva a cardinalidade
-- do catalogo e do quadro de usuarios ate uma faixa de oficina real, para que a
-- seletividade dos indices da W3 possa ser medida.
--
-- Determinismo: setseed fixo e ancora temporal fixa; reexecutar em base limpa produz
-- a mesma massa. Nenhum dado pessoal real e gerado.

SET client_min_messages = warning;
SELECT setseed(0.42);

-- ---------------------------------------------------------------------------
-- Catalogo de pecas e insumos: 2.000 novos itens
-- ---------------------------------------------------------------------------
INSERT INTO pecas_insumos (
    id, sku, nome, valor_unitario, estoque_minimo, unidade_medida, tipo_item,
    ativo, versao, data_criacao, data_ultima_atualizacao
)
SELECT gen_random_uuid(),
       'SKU-MASSA-' || lpad(g::text, 6, '0'),
       'Item de catalogo ' || g,
       round((10 + (g % 400))::numeric, 2),
       5,
       'UN',
       CASE WHEN g % 3 = 0 THEN 'INSUMO' ELSE 'PECA' END,
       true,
       0,
       TIMESTAMP '2026-03-18 00:00:00',
       TIMESTAMP '2026-03-18 00:00:00'
FROM generate_series(1, 2000) AS g;

-- ---------------------------------------------------------------------------
-- Usuarios operadores: 200 novos. cliente_id fica NULL porque uk_usuarios_cliente
-- e UNIQUE e existem apenas 5 clientes no seed.
-- ---------------------------------------------------------------------------
INSERT INTO usuarios (
    id, username, email, senha_hash, cliente_id, ativo, bloqueado,
    data_criacao, data_ultima_atualizacao
)
SELECT gen_random_uuid(),
       'operador.massa.' || lpad(g::text, 4, '0'),
       'operador.massa.' || lpad(g::text, 4, '0') || '@workshop.local',
       '$2a$10$massaDeTesteNaoUsarEmProducaoXXXXXXXXXXXXXXXXXXXXXXXXXXX',
       NULL,
       true,
       false,
       TIMESTAMP '2026-03-18 00:00:00',
       TIMESTAMP '2026-03-18 00:00:00'
FROM generate_series(1, 200) AS g;

-- ---------------------------------------------------------------------------
-- Veiculos: 2.000
-- ---------------------------------------------------------------------------
INSERT INTO veiculos (
    id, placa, marca, modelo, ano, cor, ativo, data_criacao, data_ultima_atualizacao
)
SELECT gen_random_uuid(),
       'MSS' || lpad(g::text, 4, '0'),
       (ARRAY['Fiat','Volkswagen','Chevrolet','Ford','Toyota','Honda'])[1 + (g % 6)],
       'Modelo ' || (g % 40),
       2005 + (g % 20),
       (ARRAY['preto','branco','prata','vermelho'])[1 + (g % 4)],
       true,
       TIMESTAMP '2026-03-18 00:00:00',
       TIMESTAMP '2026-03-18 00:00:00'
FROM generate_series(1, 2000) AS g;

-- ---------------------------------------------------------------------------
-- Ordens de servico: 200.000, distribuidas em 180 dias.
-- ~5% logicamente removidas (data_remocao NOT NULL) para exercitar o recorte
-- "data_remocao IS NULL" da consulta de volume diario.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE tmp_clientes AS SELECT id, row_number() OVER (ORDER BY id) AS rn FROM clientes;
CREATE TEMP TABLE tmp_veiculos AS SELECT id, row_number() OVER (ORDER BY id) AS rn FROM veiculos;

INSERT INTO ordens_servico (
    id, id_cliente, id_veiculo, status, data_remocao, data_criacao,
    data_ultima_atualizacao, numero
)
SELECT gen_random_uuid(),
       c.id,
       v.id,
       (ARRAY['RECEBIDA','EM_DIAGNOSTICO','AGUARDANDO_APROVACAO','EM_EXECUCAO',
              'FINALIZADA','ENTREGUE','CANCELADA'])[1 + (g % 7)],
       CASE WHEN g % 20 = 0
            THEN TIMESTAMP '2026-09-14 00:00:00' - ((g % 180) || ' days')::interval
            ELSE NULL END,
       TIMESTAMP '2026-09-14 00:00:00'
           - ((g % 180) || ' days')::interval
           - ((g % 1440) || ' minutes')::interval,
       TIMESTAMP '2026-09-14 00:00:00' - ((g % 180) || ' days')::interval,
       'OS-MASSA-' || lpad(g::text, 7, '0')
FROM generate_series(1, 200000) AS g
JOIN tmp_clientes c ON c.rn = 1 + (g % (SELECT count(*) FROM tmp_clientes))
JOIN tmp_veiculos v ON v.rn = 1 + (g % (SELECT count(*) FROM tmp_veiculos));

-- ---------------------------------------------------------------------------
-- Itens: 3 por OS (~600.000). 70% referenciam uma peca do catalogo; 30% ficam com
-- peca_insumo_id NULL (item de mao de obra), o que tambem exercita o indice parcial
-- implicito de uma coluna anulavel.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE tmp_os AS
SELECT id, row_number() OVER (ORDER BY id) AS rn FROM ordens_servico WHERE numero LIKE 'OS-MASSA-%';
CREATE TEMP TABLE tmp_pecas AS
SELECT id, row_number() OVER (ORDER BY id) AS rn FROM pecas_insumos;

INSERT INTO ordens_servico_itens (
    id, ordem_servico_id, ordem_item, descricao, valor, tipo, peca_insumo_id
)
SELECT gen_random_uuid(),
       o.id,
       i,
       'Item ' || i || ' da OS ' || o.rn,
       round((50 + ((o.rn * i) % 900))::numeric, 2),
       CASE WHEN ((o.rn + i) % 10) < 7 THEN 'PECA' ELSE 'SERVICO' END,
       CASE WHEN ((o.rn + i) % 10) < 7
            THEN (SELECT p.id FROM tmp_pecas p
                  WHERE p.rn = 1 + ((o.rn * 7 + i * 13) % (SELECT count(*) FROM tmp_pecas)))
            ELSE NULL END
FROM tmp_os o
CROSS JOIN generate_series(1, 3) AS i;

-- ---------------------------------------------------------------------------
-- Historico de status: 4 transicoes por OS (~800.000), respeitando o CHECK
-- status_anterior <> status_novo. usuario_id distribuido entre os ~205 usuarios.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE tmp_usuarios AS
SELECT id, username, row_number() OVER (ORDER BY id) AS rn FROM usuarios;

INSERT INTO historico_status_os (
    id, ordem_servico_id, status_anterior, status_novo, data_transicao,
    usuario_id, usuario_username, data_criacao, data_ultima_atualizacao, data_remocao
)
SELECT gen_random_uuid(),
       o.id,
       (ARRAY['RECEBIDA','EM_DIAGNOSTICO','AGUARDANDO_APROVACAO','EM_EXECUCAO'])[t],
       (ARRAY['EM_DIAGNOSTICO','AGUARDANDO_APROVACAO','EM_EXECUCAO','FINALIZADA'])[t],
       TIMESTAMP '2026-09-14 00:00:00'
           - ((o.rn % 180) || ' days')::interval
           + ((t * 6) || ' hours')::interval,
       u.id,
       u.username,
       TIMESTAMP '2026-09-14 00:00:00' - ((o.rn % 180) || ' days')::interval,
       TIMESTAMP '2026-09-14 00:00:00' - ((o.rn % 180) || ' days')::interval,
       NULL
FROM tmp_os o
CROSS JOIN generate_series(1, 4) AS t
JOIN tmp_usuarios u ON u.rn = 1 + ((o.rn * 4 + t) % (SELECT count(*) FROM tmp_usuarios));

DROP TABLE tmp_clientes, tmp_veiculos, tmp_os, tmp_pecas, tmp_usuarios;

ANALYZE pecas_insumos;
ANALYZE usuarios;
ANALYZE veiculos;
ANALYZE ordens_servico;
ANALYZE ordens_servico_itens;
ANALYZE historico_status_os;
