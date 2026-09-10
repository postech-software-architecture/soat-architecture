# Evidencias W0/W2 — validacao de cloud e workloads

Registro consolidado em 2026-09-09. Diferentemente dos JSONs de G1, este documento
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
