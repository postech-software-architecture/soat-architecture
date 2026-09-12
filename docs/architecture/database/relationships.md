# Relacionamentos e integridade referencial

## Politica geral

O schema pos-W3 esta representado em [database-er.mmd](../diagrams/database-er.mmd). A
migration `V0.20260912185705__add_integrity_constraints_to_workshop.sql` fecha quatro lacunas
de integridade e usa `ON DELETE RESTRICT` em todas elas. Registros de negocio referenciados
nao podem ser removidos fisicamente; onde existe remocao funcional, a aplicacao usa campos
como `ativo` e `data_remocao`.

As quatro constraints novas sao validadas imediatamente, e nao criadas como `NOT VALID`:

| Filho | Pai | Cardinalidade / obrigatoriedade | Ownership e motivo | Exclusao | Indice de apoio |
|---|---|---|---|---|---|
| `ordens_servico.id_cliente` | `clientes.id` | muitas OS para um cliente; obrigatoria | A OS preserva quem solicitou o atendimento. | `RESTRICT` | `ix_ordens_servico_cliente` (existente) |
| `ordens_servico.id_veiculo` | `veiculos.id` | muitas OS para um veiculo; obrigatoria | A OS preserva o veiculo efetivamente atendido. | `RESTRICT` | `ix_ordens_servico_veiculo` (existente) |
| `ordens_servico_itens.peca_insumo_id` | `pecas_insumos.id` | muitos itens para uma peca; opcional, conforme `tipo` | Item dos tipos peca/insumo referencia o catalogo e permite rastrear reserva. | `RESTRICT` | `ix_ordens_servico_itens_peca_insumo` (**novo**) |
| `historico_status_os.usuario_id` | `usuarios.id` | muitas transicoes para um usuario; obrigatoria | O historico preserva o autor da transicao para auditoria. | `RESTRICT` | `ix_historico_status_os_usuario` (**novo**) |

O teste `DatabaseIntegrityMigrationIT` esta preparado para verificar que as quatro
constraints existem e estao validadas, rejeitam registros orfaos com SQLSTATE `23503` e
impedem a exclusao dos quatro pais referenciados. Para as quatro FKs novas, ele inspeciona
dois indices existentes (`ix_ordens_servico_cliente` e `ix_ordens_servico_veiculo`) e dois
novos. Tambem preserva a verificacao de dois indices associados a FKs antigas
(`ix_ordens_servico_itens_servico` e `ix_historico_status_os_ordem_data`), totalizando seis
indices inspecionados. O resultado continua pendente da CI.

## Identidade tecnica do webhook

A FK obrigatoria de `historico_status_os.usuario_id` exige uma identidade persistida para
transicoes disparadas pelo webhook. A migration cria a conta tecnica com UUID fixo
`70000000-0000-0000-0000-000000000001`, `username = system.webhook`, `ativo = false`,
`bloqueado = true` e papel `SISTEMA`. Nao existe credencial provisionada para essa conta e o
papel tecnico nao concede acesso aos endpoints destinados a papeis humanos.

A origem externa continua auditavel no campo `historico_status_os.usuario_username`, no
formato historico `webhook:<origem>`. O remapeamento para o UUID tecnico alcanca somente
linhas desse formato cujo `usuario_id` ainda e orfao; historicos ligados a um usuario
existente nao sao alterados.

## Demais relacionamentos importantes

| Relacao | Cardinalidade / obrigatoriedade | Ownership, exclusao e auditoria | Indice |
|---|---|---|---|
| `clientes` -> `enderecos` | cliente 1 : 0..1 endereco; FK obrigatoria e unica no endereco | Endereco pertence ao cliente; `CASCADE` elimina o dependente. | `UNIQUE(cliente_id)` |
| `clientes` <-> `veiculos` | N:N por `veiculos_clientes`; ambos obrigatorios no vinculo | O vinculo tem PK composta e timestamps; exclusao usa o default restritivo. | PK `(veiculo_id, cliente_id)` + indice por `cliente_id` |
| `clientes` -> `usuarios` | cliente 0..1 : 0..1 usuario | Vinculo opcional e unico; `RESTRICT` preserva a conta associada. | unique constraint em `cliente_id` |
| `usuarios` -> `usuarios_roles` | usuario 1 : N roles | Role pertence a conta; `CASCADE` remove papeis junto com a conta. | PK `(usuario_id, role)` |
| `usuarios` -> `refresh_tokens` | usuario 1 : N tokens | Token pertence a conta; `CASCADE`; revogacao e expiracao ficam registradas. | `idx_refresh_tokens_usuario` |
| `ordens_servico` -> `ordens_servico_itens` | OS 1 : N itens; FK obrigatoria | Item pertence a OS; exclusao usa o default restritivo. | unique `(ordem_servico_id, ordem_item)` |
| `servicos` -> `ordens_servico_itens` | servico 0..1 : N itens | FK opcional para itens do tipo servico; default restritivo. | `ix_ordens_servico_itens_servico` |
| `ordens_servico` -> `historico_status_os` | OS 1 : N transicoes; FK obrigatoria | Historico pertence a OS e nao deve ser perdido; default restritivo. | `(ordem_servico_id, data_transicao)` |
| `ordens_servico` -> `orcamentos` | OS 1 : N orcamentos; FK obrigatoria | Orcamento e fotografia comercial da OS; default restritivo. | `ix_orcamentos_ordem_servico` |
| `orcamentos` -> `orcamentos_itens` | orcamento 1 : N itens; FK obrigatoria | Item fotografado pertence ao orcamento; default restritivo. | PK `(orcamento_id, ordem_item)` |
| `pecas_insumos` -> `estoques` | peca 1 : N localizacoes; FK obrigatoria | Saldo pertence ao item; `RESTRICT` evita apagar catalogo com saldo. | `idx_estoques_peca` |
| `estoques` -> `movimentacoes_estoque` | estoque 1 : N movimentos; FK obrigatoria | Movimento e trilha de auditoria do saldo; `RESTRICT`. | `idx_movimentacoes_estoque` |
| `ordens_servico` -> `movimentacoes_estoque` | OS 0..1 : N movimentos | Vinculo opcional rastreia consumo/reserva operacional; default restritivo. | `idx_movimentacoes_estoque_ordem_servico_id` |
| `orcamentos` -> `movimentacoes_estoque` | orcamento 0..1 : N movimentos | Vinculo opcional rastreia reserva/liberacao comercial; default restritivo. | `idx_movimentacoes_estoque_orcamento_id` |

`webhook_eventos_processados` nao possui FK por decisao de fronteira: ele guarda o
identificador opaco emitido por um sistema externo para idempotencia. Nao existe entidade
pai local que possa ser referenciada com integridade relacional.

O diagrama ER textual cobre 16 das 17 tabelas. `webhook_eventos_processados` e a unica
excluida por nao participar de relacionamentos; a renderizacao do diagrama em SVG/PNG ainda
esta pendente e nao constitui evidencia do G3 nesta branch.

## Regras que permanecem na aplicacao

As colunas opcionais `servico_id` e `peca_insumo_id` dependem do discriminador `tipo` do item.
O banco garante que uma referencia preenchida exista, mas a coerencia entre tipo e qual FK
deve ser preenchida continua validada pela aplicacao. Essa concessao deve ser reavaliada se
novos produtores passarem a gravar diretamente no schema.
