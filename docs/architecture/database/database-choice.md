# Escolha do banco de dados

## Decisao

A persistencia transacional da Fase 3 usa **PostgreSQL 15 no Amazon RDS**. O banco sera
criado do zero na conta AWS Academy atual, em subnets privadas, sem endpoint publico e com
acesso TCP/5432 restrito ao security group de consumidores recebido do state do cluster.

Esta pagina detalha a decisao aceita na [RFC-003](../rfc/RFC-003-database.md). A definicao
executavel fica no repositorio `workshop-infra-database`; o schema continua sendo
responsabilidade das migrations Flyway do repositorio `workshop-service-fase1`.

## Adequacao ao dominio

O nucleo do dominio e relacional: clientes e veiculos originam ordens de servico; cada ordem
tem composicao tecnica, orcamentos, movimentacoes de estoque e uma linha do tempo auditavel
de mudancas de status. Essas operacoes exigem atomicidade, consistencia e restricoes entre
registros. PostgreSQL oferece transacoes ACID, chaves estrangeiras, constraints, indices
parciais e consultas agregadas sem exigir a remodelagem da aplicacao.

A linha do tempo em `historico_status_os` e a fonte para medir **tempo por etapa**. Latencia
HTTP mede desempenho tecnico de uma requisicao e nao substitui a duracao do processo de
negocio entre duas transicoes persistidas.

## Compatibilidade e operacao

- a aplicacao ja usa PostgreSQL, JPA e Flyway; nao ha custo de migracao de tecnologia;
- todas as migrations, inclusive o seed demonstrativo, podem ser reproduzidas em uma base
  vazia;
- o RDS retira do grupo tarefas de instalar, corrigir e fazer backup do servidor PostgreSQL;
- o state do banco e separado do state do cluster e usa a chave
  `database/terraform.tfstate` no backend S3 definido pelo ADR-005;
- a senha nao e output Terraform. Ela vem de secret e, embora marcada como sensivel, fica
  cifrada no state remoto porque o provider precisa administrar a instancia.

## Alternativas rejeitadas

| Alternativa | Motivo da rejeicao |
|---|---|
| PostgreSQL dentro do EKS | Acopla dados duraveis ao ciclo de vida do cluster e transfere backup, volume e recuperacao ao grupo. |
| DynamoDB | Exige redesenhar agregados, consultas e integridade que hoje dependem do modelo relacional. |
| Aurora PostgreSQL | Traz escala, custo e complexidade operacional desnecessarios para a carga academica. |
| Banco local ou H2 em producao | Nao representa persistencia gerenciada nem os requisitos de rede, backup e disponibilidade da entrega. |

## Concessoes do ambiente academico

Para caber na janela e no orcamento do AWS Academy, a configuracao de demonstracao usa uma
instancia pequena, `single-AZ`, retencao curta de backup e sem Enhanced Monitoring (a
`LabRole` nao permite criar a role exigida). Isso e aceitavel somente no ambiente efemero da
entrega.

Em producao, a recomendacao e Multi-AZ, credenciais em AWS Secrets Manager com rotacao,
protecoes contra exclusao, janela de manutencao controlada, alarmes, Performance Insights e
politica de snapshots/retenção definida pelo negocio. O dimensionamento deve partir de
metricas reais, e nao da configuracao academica.

## Evidencia e estado

- infraestrutura e operacoes seguras preparadas no commit final `3d7afd9` de
  `workshop-infra-database`, precedido por `1971b71`, `02a1a5c` e `efb60fd`;
- migration e teste de integridade preparados no commit final `56e56d2` da aplicacao;
- associacao do `db_client_sg_id` aos nodes e gates seguros preparados no commit final
  `9e4cffd` de `workshop-infra-kubernetes`, precedido por `2130563`; CI, merge e
  `terraform plan` continuam pendentes;
- criacao do RDS, execucao real do Flyway e conectividade permanecem pendentes do checkpoint
  AWS da W3.

No encerramento desse checkpoint, o workflow do banco deve destruir e confirmar a remocao
do RDS antes que o workflow do cluster remova EKS e VPC.
