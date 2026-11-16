# Conferência final — cobertura, CI/CD e main

Base: artifacts GitHub das imagens registradas pelo workflow BDD real 43780849850. XML JaCoCo/JUnit e SpotBugs foram baixados e conferidos; não houve rebuild local.

| Serviço | Testes Maven | LINE | CI | Deploy |
|---|---:|---:|---|---|
| workshop-os-service | 387 | 83.31% | [CI](https://github.com/postech-software-architecture/workshop-os-service/actions/runs/43743930446) | [Deploy](https://github.com/postech-software-architecture/workshop-os-service/actions/runs/43744057933) |
| workshop-billing-service | 111 | 85.43% | [CI](https://github.com/postech-software-architecture/workshop-billing-service/actions/runs/43773150621) | [Deploy](https://github.com/postech-software-architecture/workshop-billing-service/actions/runs/43774200032) |
| workshop-execution-service | 77 | 86.95% | [CI](https://github.com/postech-software-architecture/workshop-execution-service/actions/runs/43652212164) | [Deploy](https://github.com/postech-software-architecture/workshop-execution-service/actions/runs/43653172074) |

Os três gates LINE ≥80% passaram; 575 testes, zero falhas/erros/skips. SpotBugs é a ferramenta similar de qualidade executada em CI, com threshold High e zero achados nos relatórios. Não atribuímos a esses runs uma análise SonarQube remota que não foi executada. Detalhes de cobertura de instruções/branches, exclusões e hashes estão no [JSON](evidencias/qualidade-ci.json).

Cada CI roda testes e build da imagem. Cada deploy é um workflow independente, iniciado manualmente por workflow_dispatch em main; depois executa testes, publicação GHCR por SHA, validação server-side, apply e rollout automaticamente. Nos runs listados o rollout passou e rollback foi pulado porque não houve falha. Isso não é deploy automático a cada merge.

Main dos três serviços e da plataforma tem ruleset ativo: PR, verify obrigatório e atualizado, sem force push/deleção e sem atores de bypass. São exigidas 0 aprovações humanas, conforme configuração adotada anteriormente pelo solicitante. prod existe, sem reviewers obrigatórios nesses quatro repositórios. Repositórios anteriores conservam proteção clássica e reviewers de prod; não alteramos regras nesta conferência. [Snapshot das regras dos serviços](evidencias/protecao-main-atual.json).

Os PRs desta consolidação são exclusivamente de documentação/metadata OpenAPI/evidências; não requerem reimplantar os serviços nem alterar o Academy. Os SHAs acima continuam identificando as imagens testadas, mesmo que a main avance por documentação.
