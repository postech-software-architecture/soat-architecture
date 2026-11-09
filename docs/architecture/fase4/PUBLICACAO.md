# Publicação e revisão

O pacote local publicacao-github-academy.zip contém o guia completo, os quatro projetos novos, os overlays dos dois repos existentes e as seis descrições de PR. Ele substitui a exportação anterior.

Criar workshop-os-service, workshop-billing-service, workshop-execution-service e workshop-infra-platform. Abrir PRs nos existentes workshop-auth-serverless e soat-architecture. Preservar monólito, cluster e RDS anteriores. Usar uma main inicial mínima nos repos novos e uma branch de implementação, abrindo Draft PR. Nos existentes, aplicar o overlay sobre o main atualizado sem apagar os arquivos não incluídos.

A publicação usa somente CLI/MCP. O conector atual não expõe criação de repos e o gh precisa de autenticação local. Conferir o acesso MCP aos novos repos após criá-los. Nenhum repo ou PR foi criado nesta preparação.

Para compartilhar: [mensagem pronta](MENSAGEM-PARA-EQUIPE.md), [resumo técnico](RESUMO-PARA-EQUIPE.md) e [checklist de revisão](CHECKLIST-DE-REVISAO.md). Configuração/corte/rollback em [ACADEMY.md](ACADEMY.md). Os links dos PRs serão preenchidos após abertura; este texto não comprova publicação.
