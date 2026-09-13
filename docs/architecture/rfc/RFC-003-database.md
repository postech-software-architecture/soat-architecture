# RFC-003 — Banco de dados gerenciado

- **Status:** aceita
- **Autores:** Grupo SOAT
- **Data:** 2026-09-12

## Contexto

O dominio possui ordens de servico, transicoes de estado, historico, estoque, clientes,
veiculos e relacionamentos transacionais. A aplicacao ja usa PostgreSQL, JPA e Flyway.
Na conta AWS alvo atual nao existe instancia RDS legada.

## Problema

Escolher a persistencia da Fase 3 e definir se o Terraform importa um banco existente ou
cria um ambiente novo.

## Requisitos e restricoes

- consistencia transacional e integridade referencial;
- migrations reproduziveis;
- banco privado, criptografado e com backup;
- state separado do cluster;
- custo compativel com o AWS Academy.

## Opcoes consideradas

1. Amazon RDS for PostgreSQL.
2. PostgreSQL em pod no EKS.
3. DynamoDB.
4. Aurora PostgreSQL.

## Comparacao

RDS preserva o modelo relacional existente e reduz operacao. PostgreSQL no cluster mistura
ciclo de vida da aplicacao e dos dados. DynamoDB exigiria remodelagem ampla. Aurora oferece
recursos alem da necessidade academica, com maior custo e complexidade.

## Proposta aceita

Criar um RDS PostgreSQL novo em subnets privadas, com `publicly_accessible = false` e
`vpc_security_group_ids` contendo somente o security group do banco. Esse grupo permite
ingresso TCP/5432 exclusivamente do `db_client_sg_id` compartilhado pelos consumidores
autorizados (nodes do EKS e Lambda), sem regra por CIDR e sem ingresso da internet.

O Terraform usa state proprio e consome outputs do cluster. O import fica como salvaguarda
condicional: antes do primeiro apply, o inventario consulta separadamente a instancia
`workshop-db`, o DB subnet group `workshop-db-subnets` e o security group
`workshop-db-sg`. Somente a ausencia dos tres torna o import nao aplicavel.

## Impactos

- a W3 precisa subir primeiro a rede do cluster;
- o plan da W3 deve provar `publicly_accessible = false` e a origem exclusiva
  `db_client_sg_id` na porta 5432;
- Flyway cria e semeia o schema novo;
- ha teste Testcontainers preparado para verificar as quatro FKs sobre base vazia + seed;
  seu resultado permanece pendente da CI;
- ao fim da janela, executar e confirmar primeiro o destroy do RDS pelo repositorio de
  banco; somente depois executar o destroy do cluster/VPC.

## Questoes em aberto

As quatro novas FKs adotam `ON DELETE RESTRICT`; dois indices existentes foram reutilizados
e dois foram acrescentados. O teste preparado ainda inspeciona dois indices de FKs antigas,
totalizando seis. A coleta numerica de `EXPLAIN (ANALYZE, BUFFERS)` permanece
pendente do checkpoint da W3 com PostgreSQL e massa representativa, conforme
[performance-review.md](../database/performance-review.md).
