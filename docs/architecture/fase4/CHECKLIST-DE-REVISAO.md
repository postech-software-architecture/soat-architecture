# Checklist de revisão dos PRs

Revisão de código e configuração; não marcar uma prova externa como concluída por ler o arquivo. Registrar comentários no PR correspondente e tratar o que for transversal no PR de arquitetura.

| PR | Pontos para conferir |
|---|---|
| OS | Autorização/propriedade, abertura idempotente, versão comercial e financeira, reserva sem baixa duplicada, reversão vinculada ao movimento, prazos/retomada e eventos fora de ordem |
| Billing | Snapshot imutável e valores decimais/centavos, dono do orçamento, intenção antes da chamada externa, chave estável após timeout, validação do recurso e webhook, estorno solicitado versus confirmado, SMTP durável |
| Execução | Contexto OS/tentativa/orçamento/pagamento, itens congelados, If-Match, disputa início/cancelamento, conclusão dos itens, transação Mongo com inbox/outbox e tombstone de cancelamento |
| Plataforma | Namespaces/seletores/secrets, bootstrap SQL e isolamento lógico no RDS compartilhado, armazenamento/driver no Academy, rotas públicas versus identidade privada, consumo de recursos, verificadores e diferenças entre dry-run e execução |
| Auth | Preservação CPF/JWT/handler, indisponibilidade sem autorização automática, token técnico e timeout, endereços Terraform e LabRole, candidata sem promoção automática, proteção do plano e rollback restrito |
| Arquitetura | Coerência do mapa/diagrama com o código, decisão de RDS físico compartilhado, critérios de aceite, evidências datadas e roteiro de implantação/retorno |

Antes de fechar os PRs: CI do destino aprovada, comentários resolvidos e pendências de ambiente identificadas. Antes do aceite da entrega: integração/BDD/provedor/cloud/restore realmente executados, participantes e links reais preenchidos, vídeo publicado. As execuções anteriores do monólito/fundação não comprovam a versão atual.
