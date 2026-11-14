Pessoal, preparei a implementação da Fase 4 para revisão. O material está separado em OS, Billing e Execução, mais uma plataforma de apoio. A autenticação e a documentação entram por PR nos repos existentes.

As lacunas técnicas levantadas foram corrigidas no código/configuração para o AWS Academy: credenciais temporárias e LabRole, borda com corte explícito, bancos e usuários separados no RDS existente, configuração Mercado Pago/SMTP, verificação de compensação e gerador do PDF com participantes. A Lambda publica uma candidata sem substituir prod automaticamente.

Já temos testes e verificações locais, mas ainda falta rodar o fluxo integrado com os bancos/broker, Mercado Pago e AWS reais. Então a revisão agora é da implementação; ainda não é homologação da entrega.

Queria que revisassem principalmente as responsabilidades dos serviços, contratos/eventos, estoque e valores, pagamentos/compensações, autorização e o corte/rollback no Academy. O resumo detalhado e o checklist indicam o que conferir em cada repo.

Links dos seis PRs:
- OS: https://github.com/postech-software-architecture/workshop-os-service/pull/1
- Billing: https://github.com/postech-software-architecture/workshop-billing-service/pull/1
- Execução: https://github.com/postech-software-architecture/workshop-execution-service/pull/1
- Plataforma: https://github.com/postech-software-architecture/workshop-infra-platform/pull/1
- Auth existente: https://github.com/postech-software-architecture/workshop-auth-serverless/pull/34
- Arquitetura existente: https://github.com/postech-software-architecture/soat-architecture/pull/24
