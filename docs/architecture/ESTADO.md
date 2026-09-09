# Estado da entrega — Fase 3

Levantamento verificado no codigo e na API do GitHub, nao nos documentos de
planejamento (que superestimam a base em vários pontos).

**Atualizado em:** 2026-09-08
**Onda atual:** W1 (fundacao) — parcialmente concluida
**Bloqueio principal:** W0 nao executada; exige credencial AWS Academy
**Ambientes:** `prod` unico. `homolog` removido dos 3 repos em 2026-09-08 (era espelho de `prod`).

---

## Resumo por onda

| Onda | Estado | Bloqueio |
|---|---|---|
| **W0** — spikes de risco | **nao iniciada** | credencial AWS + token Grafana |
| **W1** — fundacao | **~70%** | secrets vazios; ADRs dependem da W0 |
| W2 — cloud + higiene | nao iniciada | depende de G1 e do `apply` do EKS |
| W3 — dados + contrato | nao iniciada | depende da W2 |
| W4-A / W4-B | nao iniciada | depende da W3 |
| W5 — observabilidade | nao iniciada | depende do G4 |
| W6 — governanca | nao iniciada | depende do G5 |
| W7 — entrega | nao iniciada | gravar **antes** de destruir a infra |

---

## W1 — o que esta pronto

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

## W1 — o que falta

| # | Pendencia | De quem depende |
|---|---|---|
| 1 | **Preencher os 18 secrets** (placeholder hoje) | pessoa — valores reais |
| 2 | **ADR-001 / 002 / 006** | veredictos da W0 |
| 3 | **Tag `phase3-baseline`** no repo da app, antes da extracao do terraform | pode ser feito agora |
| 4 | Remover `infra/eks/**` do repo da app apos a extracao | PR coordenado |
| 5 | Required status checks na branch protection | so depois que os jobs existirem (W6) |

---

## Bloqueio: a W0 nao foi executada

Os 4 spikes vem **antes** de tudo no plano, e nenhum rodou. Consequencia pratica:
o desenho da F4 (autenticacao serverless) segue **nao validado**.

| Spike | Precisa de | Mata qual risco |
|---|---|---|
| **LabRole assumivel por Lambda** | AWS | Se o trust policy nao inclui `lambda.amazonaws.com`, **todo o desenho da F4 cai** e vira o fallback "Lambda chama endpoint da app". **Maior incognita do projeto** |
| **VPC Link + NLB interno** | AWS | Define topologia privada final vs. fallback documentado |
| **Ingest Grafana Cloud** | **so token** | Destrava a W5. Nao precisa de AWS |
| **Tempo de EKS + backend S3** | AWS | Dita a politica de cluster longevo e se o state remoto e viavel |

O spike do **Grafana e o unico que nao toca a AWS** — precisa apenas do token e um
`curl` OTLP. Pode ser feito a qualquer momento.

> Restricao vigente: por decisao do time, **nada foi provisionado na AWS** e nenhum
> `apply` foi executado. Duas travas impedem acidente: `AWS_CREDENTIALS_READY=false`
> nos 3 repos e placeholder invalido nos secrets.

---

## Divergencias verificadas (os docs de planejamento erram)

| # | Doc afirma | Realidade verificada |
|---|---|---|
| 1 | Kustomize ja existe | `k8s/` **nao existe** em `main`. Existe so na branch nao mergeada `feat/dev3-kubernetes`, com **9 arquivos em YAML puro** |
| 2 | `cd.yml` faz deploy | **No-op**: trigger so `workflow_dispatch`, `environment: production` comentado, todos os `kubectl apply` comentados, e referencia `k8s/*.yaml` **que nao existem** |
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

1. **Spike do Grafana** — o unico que nao precisa de AWS. Destrava a W5
2. **Tag `phase3-baseline`** no repo da app — pode ser feita agora
3. **Preencher os secrets** e virar `AWS_CREDENTIALS_READY` para `true`
4. **Spike da LabRole** — o mais barato dos que usam AWS, e o que pode invalidar a F4
5. Só entao a **W2** (`apply` do EKS, ~15–20 min por iteracao)

> Ordem deliberada: os itens 1–2 nao consomem credencial; o 4 e barato e pode mudar o
> desenho. Comecar pela W2 antes do 4 arrisca construir sobre premissa falsa.
