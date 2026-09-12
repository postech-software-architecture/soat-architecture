# Estado da entrega — Fase 3

Levantamento verificado no codigo e na API do GitHub, nao nos documentos de
planejamento (que superestimam a base em vários pontos).

**Atualizado em:** 2026-09-12
**Onda atual:** W2 (cloud + higiene) — parcialmente concluida
**Bloqueio principal:** concluir logs JSON/OTel e auditar orfaos antes da W3
**Ambientes:** `prod` unico. `homolog` removido dos 3 repos em 2026-09-08 (era espelho de `prod`).

---

## Resumo por onda

| Onda | Estado | Bloqueio |
|---|---|---|
| **W0** — spikes de risco | **concluida** | 4 veredictos aprovados; ADR-001/002/005/006 registrados |
| **W1** — fundacao | **parcial** | repos/CI prontos; secrets reais e ADRs pendentes |
| **W2** — cloud + higiene | **parcial** | EKS e Kustomize validados; higiene da app e logs pendentes |
| W3 — dados + contrato | nao iniciada | depende da W2 |
| W4-A / W4-B | nao iniciada | depende da W3 |
| W5 — observabilidade | nao iniciada | depende do G4 |
| W6 — governanca | nao iniciada | depende do G5 |
| W7 — entrega | nao iniciada | gravar **antes** de destruir a infra |

---

## Fundacao e cloud — o que esta pronto

| Item | Evidencia |
|---|---|
| 4 repositorios publicos e ativos | os 4 com `main` populada |
| Branch protection nos 4 | 1 aprovacao, sem force-push/delecao, stale dismiss, conversation resolution — **comprovadamente bloqueando** (`BLOCKED`/`REVIEW_REQUIRED`) |
| Environment `prod` | 3 repos de deploy; exige aprovacao (ambiente unico) |
| Secret scanning + push protection | ativo nos 4 |
| Sub-gate de seguranca | `.gitignore` cobrindo `*.tfvars`/`*.tfstate` desde o 1o commit |
| **Contrato de outputs** | 12 outputs; `terraform validate` verde com modulos reais |
| CI minima nos 3 repos novos | verde em todos |
| 9 agentes de plataforma | `.claude/agents/` no repo da app, replicados por dono |
| Runbook de secrets | [runbooks/secrets.md](runbooks/secrets.md) |
| PRs de consolidacao | Kubernetes [#2](https://github.com/postech-software-architecture/workshop-infra-kubernetes/pull/2) e [#3](https://github.com/postech-software-architecture/workshop-infra-kubernetes/pull/3), database [#2](https://github.com/postech-software-architecture/workshop-infra-database/pull/2) e arquitetura [#5](https://github.com/postech-software-architecture/soat-architecture/pull/5) mesclados |
| EKS no AWS Academy | `terraform apply` medido em ~16 min; nodes `Ready` |
| Add-ons do cluster | `metrics-server` e AWS Load Balancer Controller validados |
| Workloads Kubernetes | Kustomize presente na app (`k8s/base`, `overlays/dev` e `overlays/aws`) |
| Baseline antes da higiene | tag anotada `phase3-baseline` publicada no commit `8aed0ba` da app |

## Pendencias reais antes das proximas ondas

| # | Pendencia | De quem depende |
|---|---|---|
| 1 | Logs JSON + OpenTelemetry na app, com testes | W2/W5 |
| 2 | Auditoria read-only de orfaos e ensaio do import do RDS | W2; pre-condicao da W3 |
| 3 | `terraform plan` real nas CIs | secrets temporarios de `prod` e `AWS_CREDENTIALS_READY=true` |
| 4 | ADR-003 e ADR-004 | segregacao dos repos e contrato JWT antes da W4 |
| 5 | Required status checks na branch protection | W6, depois de estabilizar nomes dos jobs |

---

## W0 — execucao concluida

O `apply` do EKS comprovou a compatibilidade da infraestrutura com o AWS Academy e
mediu cerca de 16 minutos. Nodes, `metrics-server` e AWS Load Balancer Controller
foram validados nessa sessao. Isso e uma evidencia de execucao, nao uma afirmacao de
que o cluster permanece ativo: o procedimento do Academy exige `destroy` ao final.

O uso da `LabRole` pela Lambda e a ingestao OTLP no New Relic US foram aprovados.
O spike final comprovou API Gateway -> VPC Link -> NLB interno -> EKS com HTTP 200.

| Spike | Precisa de | Mata qual risco |
|---|---|---|
| **LabRole assumivel por Lambda** | **APROVADO** | Lambda temporaria assumiu a role, respondeu 200 e nao permaneceu listada |
| **VPC Link + NLB interno** | **APROVADO** | VPC Link `AVAILABLE`, NLB interno e proxy HTTP 200 |
| **Ingestao OTLP / New Relic US** | **APROVADO** | HTTP 200 e span localizado pelo `trace.id` no New Relic |
| **Tempo de EKS + backend S3** | **APROVADO** | backend S3 + lock DynamoDB reutilizados por dois applies; workflows protegidos |

O backend escolhido para observabilidade e **New Relic US**, mantendo OpenTelemetry
como protocolo vendor-neutral.

> A validacao foi executada manualmente em uma sessao temporaria do Academy. As CIs
> continuam protegidas por `AWS_CREDENTIALS_READY=false` enquanto os secrets de
> `prod` nao estiverem prontos para uma janela controlada.

---

## Divergencias verificadas (os docs de planejamento erram)

| # | Doc afirma | Realidade verificada |
|---|---|---|
| 1 | Kustomize ja existe | **Confirmado em `main`**: `k8s/base`, `k8s/overlays/dev` e `k8s/overlays/aws` |
| 2 | `cd.yml` faz deploy | Atualizado para aplicar o overlay `aws`; a execucao real ainda depende de secrets e de uma janela AWS valida |
| 3 | Duas `openapi.yaml` | Sao **6** arquivos, mas 4 sao contratos de spec em `specs/`. O conflito real e raiz (2015 linhas) vs. `src/.../controllers/` (3186) |
| 4 | `runAsUser: 100` | Depende da branch: `main`/`dev4` **nao fixam UID**; `dev3` usa `-u 1000`. Deve ser **derivado da imagem** |
| 5 | `/actuator/health` precisa ser liberado | **Ja esta** `permitAll()` (`SecurityConfig.java:63-64`). A obrigacao e nao estreitar |
| 6 | Recomenda New Relic | Confirmado como **OpenTelemetry + New Relic US** (ADR-006) |
| 7 | — | `/api/v1/ordens-servico/*/status` esta **publico** sem autenticacao (`SecurityConfig.java:62`) |
| 8 | — | `db_password` era **output** do terraform (state!) e `var.db_password` tinha default `"workshop"`. Corrigido na extracao |

---

## Riscos abertos, por severidade

### 1. Segredo JWT comprometido (ALTO — acao pendente)

O default de 64 hex em `application.yml:31` do repo da aplicacao esta no historico git
de um repositorio **publico** (commit `118e4b3`).

**Nao** reescrever historico: o repo ja e publico e isso quebraria os PRs que servem de
evidencia da entrega. A acao correta e **rotacionar** e tratar o valor como
permanentemente queimado. O `JWT_SECRET` real precisa ser **novo**.

Pendente: rotacao + remocao do default com fail-fast (entrega da W4-B).

### 2. Desenho da F4 validado (risco encerrado na W0)

Os spikes comprovaram que a Lambda consegue assumir a `LabRole` e que a topologia
privada responde via VPC Link e NLB interno. A W4 pode seguir conforme ADR-002.

### 3. FK sobre seed com orfaos (MEDIO — bloqueia W3)

4 FKs ausentes (`ordens_servico.id_cliente`, `.id_veiculo`,
`ordens_servico_itens.peca_insumo_id`, `historico_status_os.usuario_id`). Se o seed
tiver registros orfaos, a migration **falha e derruba o startup**. Exige auditoria
read-only **antes** de escrever a migration (W2).

### 4. `terraform import` do RDS (MEDIO — bloqueia W3)

Ja existe instancia RDS **semeada**. `apply` em state novo cria um **segundo** banco e
orfana o atual, destruindo os dados que o **G4** usa. O README do repo de banco
documenta o procedimento; um `plan` que proponha **criar** `aws_db_instance` significa
que o import nao foi feito.

### 5. Gate do JaCoCo (MEDIO — recorrente)

`BUNDLE` / `INSTRUCTION` ≥ 80%, e **nao** exclui `infrastructure/security/**`. Toda onda
que toca `src/` precisa do agente `tests` na mesma PR, ou o `verify` quebra.

### 6. Credencial de ~4h (MEDIO — operacional)

9 valores AWS a renovar por janela de trabalho (3 secrets × 3 repos). Um `apply` iniciado
perto do fim falha no meio e deixa **state parcial**.

---

## Proximo passo recomendado

1. Concluir logs JSON/OTel com testes na aplicacao.
2. Auditar orfaos das quatro FKs e ensaiar o `terraform import` do RDS.
3. Fechar o G2 com `mvn verify` e Kustomize validos.
4. Preencher secrets somente no inicio de uma janela de execucao e habilitar o
   `terraform plan` real de forma controlada.

> O EKS nao precisa ser recriado para iniciar trabalho documental ou local. A proxima
> janela AWS deve priorizar os spikes que ainda podem mudar a arquitetura.
