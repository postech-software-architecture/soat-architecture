# Evidencias W0/W2 — validacao de cloud e workloads

Registro consolidado em 2026-09-12. Diferentemente dos JSONs de G1, este documento
nao e uma captura bruta: referencia commits, PRs e comandos observados pelo time.

## Mudancas integradas

| Repositorio | PR | Resultado |
|---|---|---|
| workshop-infra-kubernetes | [#2](https://github.com/postech-software-architecture/workshop-infra-kubernetes/pull/2) | Environment unico `prod` |
| workshop-infra-kubernetes | [#3](https://github.com/postech-software-architecture/workshop-infra-kubernetes/pull/3) | Compatibilidade do EKS com AWS Academy |
| workshop-infra-database | [#2](https://github.com/postech-software-architecture/workshop-infra-database/pull/2) | Environment unico `prod` |
| soat-architecture | [#5](https://github.com/postech-software-architecture/soat-architecture/pull/5) | Documentacao de ambiente unico; merge `f0b675b` |

## Validacao manual registrada

- `terraform apply` do EKS concluido em aproximadamente 16 minutos.
- Nodes observados em estado `Ready`.
- Deployment do `metrics-server` observado disponivel.
- AWS Load Balancer Controller observado disponivel.
- Kustomize confirmado em `main` da aplicacao: `k8s/base`, `k8s/overlays/dev` e
  `k8s/overlays/aws`.

## Spikes W0 executados entre 2026-09-09 e 2026-09-12

| Spike | Evidencia | Veredicto |
|---|---|---|
| LabRole + Lambda | [Actions run 34425749565](https://github.com/postech-software-architecture/workshop-auth-serverless/actions/runs/34425749565): funcao temporaria criada, invocada com HTTP 200 e ausente da listagem ao final | **APROVADO** |
| Ingestao OTLP | [Actions run 34426760765](https://github.com/postech-software-architecture/workshop-auth-serverless/actions/runs/34426760765): New Relic US respondeu HTTP 200 | **APROVADO** |
| EKS + backend remoto | [Apply inicial 34546920538](https://github.com/postech-software-architecture/workshop-infra-kubernetes/actions/runs/34546920538) e [reaplicacao 34716391300](https://github.com/postech-software-architecture/workshop-infra-kubernetes/actions/runs/34716391300): state S3 e lock DynamoDB reutilizados; segundo plano teve `0 add, 1 change, 0 destroy` | **APROVADO** |
| VPC Link + NLB interno | [Actions run 34716577120](https://github.com/postech-software-architecture/workshop-auth-serverless/actions/runs/34716577120): VPC Link `AVAILABLE`, NLB interno e proxy HTTP responderam 200 | **APROVADO** |
| Logs JSON, OTLP e correlacao | [PR #65](https://github.com/postech-software-architecture/workshop-service-fase1/pull/65) e [CI 34718784454](https://github.com/postech-software-architecture/workshop-service-fase1/actions/runs/34718784454): testes e cobertura verdes | **APROVADO** |
| Encerramento da janela | [Destroy 34716906674](https://github.com/postech-software-architecture/workshop-infra-kubernetes/actions/runs/34716906674): 24 recursos destruidos; state S3 e lock DynamoDB preservados | **APROVADO** |

## Ajuste do cenario de dados

A conta AWS Academy usada nas proximas ondas e diferente da conta presumida pelo plano e
nao possui RDS legado. Portanto, auditoria de dados persistidos e `terraform import` ficam
`N/A` enquanto o inventario estiver vazio. A W3 cria um RDS novo e valida migrations + seed
em Testcontainers antes do primeiro apply.

A verificacao funcional no New Relic encontrou um `Span` com:

- `service.name = workshop-w0-otlp-spike`;
- `deployment.environment = prod`;
- `newrelic.source = api.traces.otlp`;
- `otel.statusCode = OK`;
- `trace.id = 4dc385e84004ef41d95a3f3e8917b336`.

O primeiro ensaio de VPC Link revelou `NoCredentialProviders` no AWS Load Balancer
Controller. O [PR #5 do repo Kubernetes](https://github.com/postech-software-architecture/workshop-infra-kubernetes/pull/5)
adotou, somente para o Academy, `hostNetwork`, `ClusterFirstWithHostNet`, uma replica
e rollout `Recreate`. A nova execucao concluiu todo o caminho e limpou os recursos
temporarios sem avisos. Fora do Academy, a decisao continua sendo IRSA ou EKS Pod Identity.

O backend definitivo usa o bucket versionado `soat-tc3-tfstate-mateus-paz`, chave
`cluster/terraform.tfstate`, e a tabela DynamoDB `soat-tc3-tflock`, todos em
`us-east-1`. Bucket e tabela foram criados fora do state para sobreviver ao destroy.

Comandos de reproducao para uma nova sessao:

```bash
aws eks update-kubeconfig --name "$(terraform output -raw cluster_name)" --region us-east-1
kubectl get nodes
kubectl -n kube-system get deploy metrics-server aws-load-balancer-controller
kubectl kustomize k8s/overlays/aws
```

## Limites desta evidencia

O AWS Academy usa credenciais temporarias e o runbook determina `terraform destroy`
ao final. Portanto, os itens acima comprovam que a configuracao funcionou na sessao,
nao que os recursos estejam ativos agora. Logs brutos da sessao nao foram anexados a
este repositorio; uma nova execucao deve salvar saidas sanitizadas se o gate exigir
prova reproduzivel.

Os arquivos em `evidence/g1/` permanecem inalterados como snapshot de 2026-09-08.
