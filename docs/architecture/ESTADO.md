# Estado da entrega — Fase 3

Levantamento verificado no codigo e na API do GitHub, nao nos documentos de
planejamento (que superestimam a base em vários pontos).

**Atualizado em:** 2026-09-09
**Onda atual:** W2 (cloud + higiene) — parcialmente concluida
**Bloqueio principal:** validar `LabRole` como execution role de Lambda antes da W4-A
**Ambientes:** `prod` unico. `homolog` removido dos 3 repos em 2026-09-08 (era espelho de `prod`).

---

## Resumo por onda

| Onda | Estado | Bloqueio |
|---|---|---|
| **W0** — spikes de risco | **parcial** | medicao do EKS feita; Lambda, VPC Link e Grafana pendentes |
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
| 1 | Remover `infra/eks/**` duplicado do repo da app | em PR coordenado; baseline ja publicada |
| 2 | Logs JSON + OpenTelemetry na app, com testes | W2/W5 |
| 3 | **Spike `LabRole` + Lambda** | credencial AWS Academy; bloqueia W4-A |
| 4 | Spike VPC Link + NLB interno | credencial AWS Academy; define ADR-002 |
| 5 | Spike de ingestao OTLP no Grafana Cloud | endpoint, instance ID e token |
| 6 | Backend S3 + lock definitivos | recursos ainda nao criados |
| 7 | `terraform plan` real nas CIs | secrets de `prod` e `AWS_CREDENTIALS_READY=true` |
| 8 | ADR-001 / 002 / 005 / 006 | registrar os veredictos dos spikes |
| 9 | Required status checks na branch protection | W6, depois de estabilizar nomes dos jobs |

---

## W0 — execucao parcial

O `apply` do EKS comprovou a compatibilidade da infraestrutura com o AWS Academy e
mediu cerca de 16 minutos. Nodes, `metrics-server` e AWS Load Balancer Controller
foram validados nessa sessao. Isso e uma evidencia de execucao, nao uma afirmacao de
que o cluster permanece ativo: o procedimento do Academy exige `destroy` ao final.

O desenho da F4 (autenticacao serverless) ainda nao esta validado.

| Spike | Precisa de | Mata qual risco |
|---|---|---|
| **LabRole assumivel por Lambda** | AWS | Se o trust policy nao inclui `lambda.amazonaws.com`, **todo o desenho da F4 cai** e vira o fallback "Lambda chama endpoint da app". **Maior incognita do projeto** |
| **VPC Link + NLB interno** | AWS | Define topologia privada final vs. fallback documentado |
| **Ingest Grafana Cloud** | **so token** | Destrava a W5. Nao precisa de AWS |
| **Tempo de EKS + backend S3** | **parcialmente concluido** | `apply` ~16 min; uso de S3 permitido, recursos definitivos ainda pendentes |

O spike do **Grafana e o unico que nao toca a AWS** — precisa apenas do token e um
`curl` OTLP. Pode ser feito a qualquer momento.

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
| 6 | Recomenda New Relic | Substituido por **OTel + Grafana Cloud** (ADR-006) |
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

### 2. Desenho da F4 nao validado (ALTO — bloqueia W4-A)

Sem o spike da LabRole, nao se sabe se a Lambda consegue assumir a role. O repo
`workshop-auth-serverless` existe e esta esperando essa resposta. A W4-A e o
**caminho critico** do projeto (3 dependencias externas contra 1 da trilha da app).

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

1. **Spike da LabRole com uma Lambda minima**; registrar o veredicto no ADR-001.
2. Em paralelo, executar os spikes de **VPC Link + NLB** e **ingestao OTLP**.
3. Remover `infra/eks/**` duplicado da app e concluir logs JSON/OTel com testes.
4. Preencher secrets somente no inicio de uma janela de execucao e habilitar o
   `terraform plan` real de forma controlada.

> O EKS nao precisa ser recriado para iniciar trabalho documental ou local. A proxima
> janela AWS deve priorizar os spikes que ainda podem mudar a arquitetura.
