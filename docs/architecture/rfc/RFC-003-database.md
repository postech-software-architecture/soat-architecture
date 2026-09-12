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

Criar um RDS PostgreSQL novo, privado, em subnets privadas e com ingresso 5432 somente do
security group de clientes. O Terraform usa state proprio e consome outputs do cluster.
O import fica como salvaguarda condicional: antes do primeiro apply, o inventario RDS e
consultado; com inventario vazio, nao ha recurso a importar.

## Impactos

- a W3 precisa subir primeiro a rede do cluster;
- Flyway cria e semeia o schema novo;
- as quatro FKs sao validadas em Testcontainers sobre base vazia + seed;
- o banco deve ser destruido antes da VPC ao fim da janela.

## Questoes em aberto

Definir na W3 as politicas `ON DELETE`, os indices de apoio e os `EXPLAIN` documentados.
