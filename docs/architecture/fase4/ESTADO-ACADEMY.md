# Correção das lacunas técnicas — AWS Academy

Concluído localmente em 09/11/2026. Este documento sucede as auditorias e o pacote de publicação anteriores; não é prova de implantação.

| Lacuna | Alteração implementada | Verificação / limite |
|---|---|---|
| Academy/IAM/workflows | Credenciais temporárias com SESSION_TOKEN e Environment prod. Lambda reutiliza LabRole e os 14 endereços de recursos existentes. Guard rejeita IAM/EKS/RDS e delete/replace de legado | Terraform fmt/validate aprovados, recursos comparados e testes do guard; sem plan/apply remoto |
| Borda existente | NLB interno adicional, listeners separados negócio/identidade; API Gateway/VPC Link e fallback preservados. Rotas novas opt-in. Versão candidata publicada sem mover prod implicitamente; seleção de versão e teste da candidata antes do corte | Kustomize e sintaxe aprovados, guarda de cutover/rollback implementada; sem rollout real |
| Dados | OS/Billing em bancos lógicos/usuários distintos no RDS atual; bootstrap não adota outro proprietário nem rotaciona senha silenciosamente. Mongo/Rabbit mantêm PVCs; preflight exige StorageClass/driver/controller já permitidos | Estrutura/roles verificadas; sem bootstrap real. RDS físico compartilhado explicitamente documentado; não se substitui o state anterior |
| Configuração local e Lambda | configure preserva secrets e gera AUTH_SERVICE_TOKEN ausente. Overrides MP/SMTP opt-in com interpolação obrigatória. Variáveis HTTP fornecidas ao CD da Lambda, sem DB_*; SMTP mapeado no Billing. Secrets gerados com nomes compatíveis com os deployments | Testes de upgrade/configuração e execução do preparador do workflow passaram; Billing 102 testes e qualidade aprovados |
| Compensação | verify-phase4 consulta o recurso diretamente no provedor, confronta identidade/valor/conta/referência, exige estorno confirmado e movimento único com saldo exato; repete cancelamento. Sem acesso SQL externo | Casos negativos de duplicidade, valor, saldo, recurso e confirmação passaram; prova externa não executada |
| PDF | Entrada real de participantes, validação de campos/duplicados, 5 pessoas, links e flags literais de provas, inclusive BDD completo. Gerador portátil no repo plataforma | Testes, renderização com 5 identificações fictícias SOMENTE em work e inspeção visual. Modo final recusou entrada vazia; nenhum nome real inventado |

## Evidências locais

22 testes novos de ferramentas/contratos/limites, com subcasos negativos, e 102 testes do Billing nesta rodada. OS 377, Execução 76 e Lambda 15 permanecem evidências anteriores; não foram executados novamente por não haver alteração de comportamento nesses runtimes. Não somar dry-run do BDD como teste integrado aprovado. Terraform validado com provider local; manifests renderizados; scripts de workflow conferidos por sintaxe. Nenhum Docker, apply, cobrança ou serviço permanente foi iniciado.

## O que continua manual/externo

Configurar os valores reais, sessão e recursos Academy existentes, conta/app/POS e webhook Mercado Pago, pagar pela conta de teste, executar integração/BDD/compensação/restore/rollout, preencher participantes, publicar repos e gravar vídeo. O preflight aborta se o lab não oferecer o driver ou permissão necessários; ele não cria IAM ou substitui o cluster para contornar a restrição.

## Publicação

Usar o novo pacote publicacao-github-academy.zip. O ZIP anterior preserva a proposta superada e não deve ser aplicado. Mantêm-se quatro repos novos e PRs nos existentes auth/arquitetura. O overlay auth agora inclui infra e workflows adaptados sobre os endereços existentes, não a proposta de função/role nova. A pasta infra/fase4 ou docs/proposta-infra antiga não deve ser aplicada em paralelo.

Consultar fase-4/ops/ACADEMY.md no workspace, ou docs/ACADEMY.md no pacote de cada componente de apoio. O corte ocorre depois de testar a versão candidata; rollback é deliberado e limitado às rotas adicionais e ao alias numerado. A aplicação, o NLB e o RDS anteriores continuam preservados até essa decisão.
