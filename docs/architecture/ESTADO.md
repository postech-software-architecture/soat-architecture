# Estado da entrega — Fase 3

Levantamento baseado no codigo, nos workflows executados e no ambiente AWS Academy
efetivamente usado pelo grupo. Quando o planejamento original diverge da execucao, o
estado real registrado aqui prevalece.

**Atualizado em:** 2026-09-12

**Onda atual:** W3 — dados + contrato

**Situacao:** W0, W1 e W2 concluidas

**Ambiente:** `prod` unico; credenciais temporarias do AWS Academy sao renovadas por janela.

---

## Resumo por onda

| Onda | Estado | Evidencia ou proximo gate |
|---|---|---|
| **W0 — spikes de risco** | **concluida** | LabRole, VPC Link/NLB, OTLP/New Relic e backend remoto aprovados |
| **W1 — fundacao** | **concluida** | 4 repositorios, protecoes, CI minima, contrato de outputs, RFCs e ADRs publicados |
| **W2 — cloud + higiene** | **concluida** | EKS/Kustomize validados; logs JSON/OTLP e correlacao integrados; CI verde; destroy comprovado |
| **W3 — dados + contrato** | **em execucao** | quatro trilhos preparados; CI, merge, plans, RDS, Flyway e `EXPLAIN` real pendentes |
| W4-A / W4-B | nao iniciada | depende do G3; contrato JWT ja congelado no ADR-004 |
| W5 — observabilidade | nao iniciada | depende do G4 |
| W6 — governanca | nao iniciada | depende do G5 |
| W7 — entrega | nao iniciada | gravar antes de destruir a infraestrutura final |

## W0 — quatro riscos encerrados

| Spike | Veredicto | Evidencia |
|---|---|---|
| LabRole assumivel por Lambda | aprovado | Lambda temporaria respondeu 200 e foi removida |
| VPC Link + NLB interno | aprovado | VPC Link `AVAILABLE` e proxy pelo API Gateway respondeu 200 |
| Ingestao OTLP / New Relic US | aprovado | endpoint respondeu 200 e o span foi localizado pelo `trace.id` |
| Tempo de EKS + backend S3 | aprovado | apply/destroy medidos; S3 e DynamoDB preservados |

Os veredictos estao detalhados em [evidence/w0-w2/README.md](evidence/w0-w2/README.md)
e fundamentam os ADR-001, ADR-002, ADR-005 e ADR-006.

## W1 — fundacao concluida

| Item | Estado |
|---|---|
| 4 repositorios publicos e ativos | concluido |
| Branch protection e secret scanning | concluido e comprovado bloqueando merge sem aprovacao |
| Environment `prod` nos repos de deploy | concluido |
| Contrato de outputs da infraestrutura | concluido, com 12 outputs |
| CI minima nos repos novos | concluido |
| RFC-001 a RFC-004 | aceitas e versionadas |
| ADR-001 a ADR-006 aplicaveis ate esta onda | publicados; ADR-003/004 congelam a W4 |

Credenciais do AWS Academy nao sao secrets permanentes da fundacao. Elas expiram em
aproximadamente quatro horas e sao renovadas apenas no inicio de cada janela controlada,
conforme [runbooks/secrets.md](runbooks/secrets.md). Esse comportamento operacional nao
mantem a W1 aberta.

## W2 — cloud e higiene concluidas

O cluster foi criado no AWS Academy, os nodes ficaram `Ready`, e `metrics-server`, AWS
Load Balancer Controller e workloads Kustomize foram validados. O fluxo privado
API Gateway -> VPC Link -> NLB -> EKS respondeu HTTP 200.

Na aplicacao, o
[PR #65](https://github.com/postech-software-architecture/workshop-service-fase1/pull/65)
adicionou logs JSON em `prod`, exportador de metricas OTLP desligado por padrao,
`X-Correlation-ID`, extracao de `traceparent` e limpeza do MDC. A
[CI 34718784454](https://github.com/postech-software-architecture/workshop-service-fase1/actions/runs/34718784454)
passou com testes e cobertura.

Ao final, o
[destroy 34716906674](https://github.com/postech-software-architecture/workshop-infra-kubernetes/actions/runs/34716906674)
removeu 24 recursos e preservou o objeto de state no S3 e a tabela de lock no DynamoDB.

## Cenario de dados corrigido para a W3

O planejamento original pressupunha uma instancia RDS semeada no mesmo ambiente e, por
isso, tornava obrigatorios uma auditoria read-only de orfaos e um `terraform import`.
O ambiente alvo atual usa **outra conta AWS Academy e comeca sem instancia RDS**.

Consequencias:

- import de RDS, subnet group e security group: **nao aplicavel** somente quando a consulta
  individual confirmar a ausencia dos tres objetos gerenciados;
- auditoria de dados persistidos: **nao aplicavel**, pois nao ha base legada nessa conta;
- integridade do seed: continua obrigatoria e sera provada na W3 por Testcontainers,
  executando todas as migrations e as quatro FKs sobre uma base vazia;
- antes do primeiro `apply`, consultas read-only devem confirmar separadamente que nao
  existem a instancia `workshop-db`, o DB subnet group `workshop-db-subnets` e o security
  group `workshop-db-sg` (por nome/tag e VPC). Uma lista vazia apenas de instancias RDS nao
  libera o apply. Se qualquer um desses objetos existir, o fluxo muda para reconciliacao e
  import do objeto correspondente; nenhum apply e permitido antes disso.

## Decisoes e riscos ainda abertos

| Item | Tratamento |
|---|---|
| Segredo JWT historico esta comprometido | default ja removido; gerar valor novo na janela da W4 e nunca reutilizar o valor do historico |
| Duas OpenAPI divergentes | trilho final `16cbb7a` (precedido por `1602856`): raiz 3.1 como unica fonte canônica de runtime, `{numero}` corrigido e copia de `src` removida; CI/merge pendentes apos o safety CD `e9bb066` |
| Quatro FKs ausentes | trilho final `f62898b` (precedido por `56e56d2`): migration com `ON DELETE RESTRICT`, dois indices existentes reutilizados, dois novos e teste preparado para verificar base vazia + seed; CI/merge pendentes apos o safety CD `e9bb066` |
| Nodes sem identidade de cliente do banco | trilho final `97fd209` (precedido por `2130563` e `9e4cffd`) associa `db_client_sg_id` ao node group e protege o destroy; CI, merge e `terraform plan` pendentes |
| Credenciais temporarias | renovar no inicio da janela; nao iniciar apply perto da expiracao |
| Required status checks definitivos | W6, depois que os nomes dos jobs estabilizarem |

## W3 em execucao

Os trilhos paralelos produziram artefatos locais ainda nao equivalentes a entrega implantada:

1. Terraform de banco no commit final `3d7afd9` (precedido por `1971b71`, `02a1a5c` e
   `efb60fd`), preparado para criacao nova, inventario/import condicional e operacoes
   seguras;
2. safety CD da aplicacao no commit `e9bb066`, que exige deploy manual durante a W3 e deve
   ser mergeado antes dos trilhos de migration e OpenAPI;
3. migration e teste no commit final `f62898b` (precedido por `56e56d2`), preparados para
   verificar quatro FKs `ON DELETE RESTRICT`, o seed e seis indices inspecionados;
4. OpenAPI no commit final `16cbb7a` (precedido por `1602856`), com a raiz eleita como unica
   fonte canônica de runtime e a copia de `src` removida;
5. acesso do cluster no commit final `97fd209` (precedido por `2130563` e `9e4cffd`),
   preparado para associar `db_client_sg_id` aos nodes do EKS e bloquear o destroy enquanto
   o security group do banco existir;
6. ER pos-FK e documentacao de dados preparados em
   [evidence/w3/README.md](evidence/w3/README.md).

O proximo passo e levar os trilhos por CI/revisao/merge. Depois, abrir uma janela AWS para
subir VPC/EKS, criar o RDS, executar Flyway, validar a conexao, coletar `EXPLAIN` real e
preservar evidencias antes do destroy. O encerramento da janela deve destruir **primeiro o
RDS pelo repositorio de banco e somente depois o cluster/VPC**. Ate la, o Gate G3 permanece
aberto.
