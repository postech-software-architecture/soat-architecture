# Aceite técnico e entrega restante

| Requisito do enunciado | Evidência / estado |
|---|---|
| ≥3 microserviços, repositórios e deploys próprios | OS/Billing/Execução, CI/deploy por serviço e imagens registradas no BDD |
| SQL e NoSQL, ownership de dados | PostgreSQL lógico separado por domínio no RDS e Mongo de Execução; isolamento físico RDS é uma concessão explícita do Academy |
| Mensageria e Saga com compensação | Rabbit/inbox/outbox, coordenador persistido em OS; OS 07/10 e timeout histórico da OS 06 |
| Testes e cobertura ≥80% | CI e contadores JaCoCo das imagens: OS 83,31%, Billing 85,43%, Execução 86,95% LINE |
| Pelo menos um fluxo completo BDD | OS 11 ENTREGUE; Cucumber/JUnit 1 cenário/5 passos, dry-run=false |
| Qualidade automatizada | SpotBugs e JaCoCo no CI, além do build Docker |
| Main com PR/checks | Rulesets ativos nos três serviços e plataforma; verify obrigatório e sem force push/deleção |
| Observabilidade | Dados/capturas de spans, logs e métricas; limites descritos em OBSERVABILIDADE.md |
| API e arquitetura documentadas | OpenAPI por serviço, arquitetura/Saga e diagrama geral consolidados |
| Vídeo de até 15 minutos | **Pendente — solicitante fará amanhã** |
| PDF institucional e envio no portal | **Pendente — solicitante fará amanhã** |

O PDF pede participantes/identificação, links dos repositórios e vídeo, diagrama final, estratégia da Saga e justificativas dos domínios/tecnologias. Esses materiais não estão declarados como publicados. SMTP desativado, HA, benchmark, ensaios adicionais de concorrência/restauração e manutenção dos assets New Relic são limites/itens operacionais; não os convertemos automaticamente em novos bloqueios do enunciado. A correlação de logs ao trace específico permanece não demonstrada e deve ser apresentada com honestidade.

Não é necessário recriar as contas MP, infraestrutura, bancos ou seeds para consultar as provas. Não apagar o ambiente ou os relatórios antes de terminar a gravação e guardar os materiais. As imagens/documentos locais podem ser consultados mesmo se o lab estiver parado.
