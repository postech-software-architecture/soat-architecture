# Runbook — Setup do New Relic (APM Java)

**Status:** spike exploratório concluído em 2026-09-09. **Não é decisão de arquitetura.**

> ⚠️ O ADR-006 vigente no plano define **OpenTelemetry + Grafana Cloud**. Este runbook
> documenta um spike de New Relic pedido para avaliar complexidade. Enquanto o ADR-006 não
> for reescrito, **o backend oficial continua sendo o Grafana Cloud**. Ver
> [ESTADO.md](../ESTADO.md) e [index.md](../index.md).

---

## Resumo

O agente Java do New Relic instrumenta bytecode em runtime via `-javaagent`. **Zero linhas
de código** na aplicação: nenhuma dependência no `pom.xml`, nenhuma anotação, nenhum
`logback-spring.xml`.

| Ambiente | Tempo medido | Trabalho |
|---|---|---|
| Host (jar direto) | ~3 min | baixar agente + 2 variáveis de ambiente |
| Kubernetes (kind) | ~8 min | camada no Dockerfile + Secret + env no Deployment |

O delta entre os dois é **empacotamento**, não instrumentação.

---

## Pré-requisito: a license key correta

**A causa de 100% das falhas deste spike foi chave errada.** O New Relic tem vários tipos
de chave e só um funciona no agente APM.

| Tipo | Formato | Serve para o agente? |
|---|---|---|
| **INGEST - LICENSE** | 40 caracteres, termina em `NRAL` | **sim — é esta** |
| INGEST - BROWSER | 64 hex | não (RUM no navegador) |
| USER | prefixo `NRAK-` | não (NerdGraph / API) |

Onde obter: [one.newrelic.com](https://one.newrelic.com) → nome do usuário (canto inferior
esquerdo) → **API keys** → filtrar por tipo **INGEST - LICENSE** → *Copy key*.

> Uma chave de 64 caracteres hexadecimais **não é** license key. Cuidado: esse é exatamente
> o formato do `JWT_SECRET` deste projeto — confundir os dois já aconteceu.

### Diagnóstico

O dashboard vazio não diz nada. **O log do agente diz tudo:**

```bash
grep -iE 'Reporting to|Invalid license' <caminho>/newrelic/logs/newrelic_agent.log
```

| Saída | Significado |
|---|---|
| `Reporting to: https://one.newrelic.com/redirect/entity/...` | conectado; a URL é o dashboard |
| `Invalid license key, the agent is no longer reporting` | chave errada ou não chegou ao processo |

O agente falha **silenciosamente no dashboard** e **barulhentamente no log**. Sempre comece
pelo log.

---

## Caminho A — Host (avaliação rápida)

### 1. Baixar o agente

```bash
cd /tmp && curl -L -o newrelic-java.zip \
  https://download.newrelic.com/newrelic/java-agent/newrelic-agent/current/newrelic-java.zip
unzip -o newrelic-java.zip
```

### 2. Subir o banco

```bash
docker compose up -d postgres
```

O `application.yml` default já aponta para `localhost:5433` com as credenciais do
compose. **Não** use `SPRING_PROFILES_ACTIVE=docker` fora do cluster — esse profile
resolve `DB_HOST=postgres`, que só existe dentro do Kubernetes.

### 3. Buildar e rodar

```bash
./mvnw clean package -DskipTests

NEW_RELIC_LICENSE_KEY=<INGEST-LICENSE> \
NEW_RELIC_APP_NAME=workshop-service-local \
JWT_SECRET=<64 hex> \
java -javaagent:/tmp/newrelic/newrelic.jar \
     -jar target/workshop-service-0.0.2-SNAPSHOT.jar
```

**Tudo numa invocação só.** Variáveis prefixadas valem apenas para o comando seguinte; se
o `java` for para outra linha, elas se perdem e o agente cai no placeholder de fábrica do
`newrelic.yml` — que produz exatamente `Invalid license key`.

O `JWT_SECRET` é obrigatório: a aplicação tem fail-fast e **se recusa a subir** com segredo
menor que 32 caracteres. Para local, use o valor dummy de `k8s/overlays/dev/secret.env`.

### 4. Gerar tráfego

```bash
for i in $(seq 1 30); do curl -s -o /dev/null localhost:8080/actuator/health; done
```

Sem requisições o APM fica vazio mesmo conectado.

### 5. Abrir

[one.newrelic.com](https://one.newrelic.com) → **APM & Services** → `workshop-service-local`.
Primeiro harvest em ~60s.

---

## Caminho B — Kubernetes

### 1. Imagem com o agente

Camada **separada** sobre a imagem da aplicação, para não invalidar o cache do build:

```dockerfile
FROM workshop-service:local

USER root
RUN apk add --no-cache unzip curl \
 && curl -sL -o /tmp/nr.zip https://download.newrelic.com/newrelic/java-agent/newrelic-agent/current/newrelic-java.zip \
 && unzip -q /tmp/nr.zip -d /opt \
 && rm /tmp/nr.zip \
 && chown -R 1000:1000 /opt/newrelic
USER spring:spring

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-javaagent:/opt/newrelic/newrelic.jar", "-jar", "/app/app.jar"]
```

O `chown 1000:1000` é obrigatório: a imagem roda como `spring` (UID 1000) e o agente
escreve log em `/opt/newrelic/logs/`. Sem isso o container sobe mas o agente falha ao
inicializar.

```bash
docker build -f Dockerfile.newrelic -t workshop-service:nr .
kind load docker-image workshop-service:nr --name workshop
```

### 2. Secret com a license key

```bash
kubectl -n workshop create secret generic newrelic-license \
  --from-literal=NEW_RELIC_LICENSE_KEY='<INGEST-LICENSE>'
```

### 3. Aplicar

```bash
kubectl -n workshop set image deployment/workshop-service \
  workshop-service=workshop-service:nr

kubectl -n workshop set env deployment/workshop-service \
  NEW_RELIC_APP_NAME=workshop-service-k8s NEW_RELIC_LABELS='env:kind'

kubectl -n workshop set env deployment/workshop-service \
  --from=secret/newrelic-license

kubectl -n workshop rollout status deployment/workshop-service
```

### 4. Verificar dentro do pod

```bash
POD=$(kubectl -n workshop get pods -l app.kubernetes.io/name=workshop-service \
      -o jsonpath='{.items[0].metadata.name}')

kubectl -n workshop exec $POD -- \
  grep -ihE 'Reporting to|Invalid license' /opt/newrelic/logs/newrelic_agent.log
```

> O label é `app.kubernetes.io/name`, **não** `app`.

### 5. Tráfego

```bash
kubectl -n workshop port-forward svc/workshop-service 8090:8080 &
for i in $(seq 1 30); do curl -s -o /dev/null localhost:8090/actuator/health; done
```

Cada `NEW_RELIC_APP_NAME` distinto vira uma **entidade separada** no APM; os pods aparecem
como instâncias dentro dela.

---

## Cobertura dos 6 dashboards da entrega

| Dashboard | `-javaagent` entrega? |
|---|---|
| Latência (p50/p95/p99) | **sim**, pronto |
| CPU / memória (JVM, GC) | **sim**, pronto |
| Uptime | **sim**, pronto |
| Erros de integração | **sim**, pronto |
| **Volume diário de OS** | **não** — métrica de negócio |
| **Tempo médio por etapa** | **não** — métrica de negócio |

Os dois últimos exigem instrumentação manual **em qualquer backend** (New Relic ou
Grafana) — não é diferencial entre eles.

Restrições que permanecem, independentemente do backend:

- **Tempo por etapa** vem de `historico_status_os`, **não** de timer de request. Confundir
  latência HTTP com tempo-em-status é risco de nota.
- **ArchUnit**: a métrica de negócio precisa de porta em `application/` + adapter em
  `infrastructure/`.
- **JaCoCo** (BUNDLE 80% INSTRUCTION): qualquer código novo em `src/` exige testes na mesma
  PR, ou o `verify` quebra.

---

## Se o New Relic for adotado

Este runbook cobre um spike descartável. Para valer como entrega, muda:

1. Agente no **Dockerfile versionado**, em camada própria
2. License key via **Environment secret** do GitHub, como os `AWS_*`
3. `NEW_RELIC_APP_NAME` por overlay (`workshop-service-prod`) e `NEW_RELIC_LABELS` por ambiente
4. **ADR-006 reescrito**, registrando a reversão e o motivo
5. Secrets `GRAFANA_*` substituídos por `NEW_RELIC_LICENSE_KEY` em
   [secrets.md](secrets.md) — 3 secrets viram 1
6. Spike de ingest da W0 reapontado para New Relic (continua sendo o único que não precisa
   de AWS)

Nada disso é difícil, mas são **PRs coordenados em repos com branch protection**, não
`kubectl set env`.

### Instrumentação OTel é reaproveitável

New Relic ingere **OTLP nativamente**. Se a app for instrumentada com OpenTelemetry
(micrometer-otlp, logback JSON, MDC/`traceparent`) conforme o plano original, trocar de
backend muda **apenas o endpoint e a autenticação do exporter** — o código permanece.

Também é possível exportar para os **dois** backends simultaneamente via OTel Collector,
sem escolher um.

---

## Limpeza do spike

```bash
kubectl -n workshop delete secret newrelic-license
kubectl -n workshop set image deployment/workshop-service \
  workshop-service=workshop-service:local
docker rmi workshop-service:nr
rm -rf /tmp/newrelic
```

**Revogue a license key** usada em spike: *API keys* → menu da linha → *Delete*. Chaves que
transitaram por chat, log ou histórico de shell devem ser tratadas como queimadas — o
projeto já carrega um incidente assim com o `JWT_SECRET` (ver [ESTADO.md](../ESTADO.md),
risco #1).
