# Fase 4 — o que foi implementado e o que revisar

Atualizado em 09/11/2026, após as correções técnicas para o AWS Academy. Este documento substitui o resumo que apresentava essas correções como lacunas de desenvolvimento abertas. Os repositórios novos e os seis PRs foram publicados (links em [MENSAGEM-PARA-EQUIPE.md](MENSAGEM-PARA-EQUIPE.md)). Em 10/11/2026 a integração foi verificada localmente (Compose e overlays Academy num k3s local): BDD completo até ENTREGUE e compensações de estorno, recusa, expiração e cancelamento até COMPENSADA, com o Mercado Pago substituído pelo mock da Orders API da plataforma. Conta de teste Mercado Pago, SMTP e cloud ainda precisam de evidências reais.

## Organização da mudança

| Componente | Responsabilidade e implementação | Destino |
|---|---|---|
| OS | Cadastros, catálogo, ordens, composição, estoque, histórico e Saga persistida. Reserva/consumo/reversão devem ocorrer uma única vez. Coordena próximos comandos e recuperação | Novo workshop-os-service |
| Billing | Orçamento imutável/versionado, decisão, notificações duráveis, intenções financeiras, reconciliação, adapter Mercado Pago e webhook que solicita consulta verificada | Novo workshop-billing-service |
| Execução | Diagnóstico, responsável, fila, itens autorizados, progresso técnico e cancelamento condicional em Mongo. Alterações exigem versão esperada | Novo workshop-execution-service |
| Plataforma | Recursos runtime adicionais, bootstrap de dados, broker/ACLs, entrada privada, telemetria, Compose, BDD, scripts de aceitação/operação e gerador de relatório | Novo workshop-infra-platform |
| Autenticação | Consulta HTTP de identidade em OS substitui JDBC. Preserva contrato CPF/JWT e adapta infra/CD existentes ao Academy | PR em workshop-auth-serverless |
| Arquitetura | Visão consolidada, decisões, evidências, runbooks, pendências e roteiro da demonstração | PR em soat-architecture |

O monólito workshop-service-fase1 e os repos workshop-infra-kubernetes/workshop-infra-database ficam preservados nesta rodada. O quarto repo novo organiza apoio, sem representar um quarto microsserviço obrigatório.

## Fluxo de negócio e consistência

Abertura da OS → diagnóstico → composição/reserva → orçamento → aprovação → cobrança → confirmação financeira verificada → reparo → finalização/entrega. Rejeição preserva a proposta anterior e abre nova versão. Pagamento antes do reparo é uma decisão do projeto.

Saga orquestrada em OS, com estado persistido, prazos e retomada. Cada participante mantém sua transação local com inbox/outbox; não há transação única entre os bancos. Mensagens podem se repetir. Compensação exige confirmação técnica antes de finanças e de reversão de estoque. Reparo físico iniciado tem recusa de cancelamento e recuperação de negócio.

## Correções técnicas já implementadas

1. Deploy usa credenciais temporárias com AWS_SESSION_TOKEN, LabRole e Environment prod; os templates OIDC/criação de role foram substituídos.
2. NLB interno adicional separa negócio e identidade. API Gateway/VPC Link e fallback anteriores são preservados; rotas fase4 são opt-in. A candidata Lambda não promove prod implicitamente. Há teste da candidata, seleção de versão e rollback restrito. O guard rejeita alterações destrutivas de legado e gerenciamento IAM/EKS/RDS.
3. OS e Billing usam bancos lógicos e usuários distintos no RDS existente. Não são instâncias físicas separadas. Bootstrap verifica proprietário/credenciais, sem substituir RDS ou seu state. Mongo/Rabbit dependem de armazenamento já permitido pelo lab; não foi prometida alta disponibilidade.
4. Compose tem overrides opt-in para MP/SMTP e geração preservadora de AUTH_SERVICE_TOKEN. A Lambda recebe IDENTITY_URL/AUTH_SERVICE_TOKEN; DB_* saiu da função. SMTP está mapeado no Billing.
5. O verificador de compensação consulta diretamente o provedor, confronta recurso/conta/referência/valor, exige estorno confirmado e movimento único com saldo correto; repete cancelamento para detectar duplicidade.
6. O gerador do PDF recebe participantes reais e recusa campos ausentes/duplicados, links inválidos ou falta de provas, inclusive BDD integrado. Nomes fictícios foram usados somente no teste do gerador.

## O que foi verificado

| Evidência | Resultado e limite |
|---|---|
| Novos testes de ferramentas, configuração, participantes e guardas | 22 aprovados nesta rodada, com casos negativos |
| Billing após a configuração SMTP | 102 testes, gate de cobertura de linhas e SpotBugs HIGH aprovados nesta rodada |
| Cópia exportada da plataforma | 14 casos repetidos aprovados; não são 14 testes novos a somar aos 22 |
| Terraform auth | fmt/validate locais aprovados; 14 endereços de recursos anteriores preservados. Sem plano real ou apply |
| Exportação | 11 workflows e 60 scripts embutidos conferidos por sintaxe; manifests dos quatro repos novos renderizados |
| PDF | Entrada/guardas testadas e renderização com participantes de teste conferida visualmente |
| OS, Execução e Lambda | 377, 76 e 15 testes, respectivamente, em execuções anteriores; não foram repetidos nesta rodada |

BDD completo foi implementado, mas teve apenas dry-run de compilação/ligação dos steps. O JSON Cucumber pode indicar passed nesse modo; isso não prova execução do fluxo real.

## O que ainda depende de execução ou informação real

Conta/aplicação/POS e comprador Mercado Pago, webhook HTTPS, credenciais e IDs reais; sessão Academy ativa e pré-requisitos disponíveis; testes SQL/Mongo/Rabbit e BDD integrado; pagamento/estorno, concorrência e retomada; rollout, restore e telemetria reais; participantes, publicação dos repos, CI remoto, proteções e vídeo.

O preflight aborta se o lab não disponibilizar a permissão ou o driver necessário; não cria IAM nem substitui o cluster para contornar a restrição. Não houve Docker, pagamento, apply cloud ou corte real nesta preparação.

## Pedido de revisão

Abrir seis Draft PRs e vincular a discussão pelo PR de arquitetura. Revisar o diff contra o main atualizado; a CI de cada destino precisa confirmar o conjunto publicado, especialmente o overlay de auth. Criticar fronteiras e contratos, autorização, transações, duplicidade/ordem de eventos, precisão monetária/estoque, recuperação com resultado financeiro desconhecido e o corte/rollback no Academy. Aprovação de código não substitui homologação ou execução do deploy.
