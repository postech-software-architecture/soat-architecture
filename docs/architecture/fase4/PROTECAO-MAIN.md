# Proteção da main nos novos repositórios

Solicitação incorporada: os quatro repos novos devem impedir commits diretos na main após o bootstrap mínimo. A proteção ainda não foi configurada remotamente porque os repos não foram criados.

## Situação conferida nos existentes

Em 09/11/2026, o MCP retornou main protegida em workshop-auth-serverless, workshop-infra-kubernetes, workshop-infra-database e soat-architecture. workshop-service-fase1 retornou protected=false e ruleset block-main desativado. O resumo de checks retornou contexts vazios/enforcement off. Isso não informa, por si só, as exigências de aprovação e os bypasses existentes.

As consultas completas de branch protection retornaram 403 Resource not accessible by integration. Portanto, não afirmar que as regras completas dos cinco repos foram auditadas ou que já exigem o padrão abaixo. Evidências resumidas em protecao-main-consulta.json, sem dados pessoais de commits.

## Configuração preparada para os quatro novos

- Pull request obrigatório, com pelo menos uma aprovação.
- Invalidar aprovações após novos commits.
- CI obrigatória e branch atualizada antes do merge.
- Resolver conversas antes do merge.
- Aplicar a proteção aos administradores.
- Bloquear force push e exclusão da main.

protecao-main-proposta.json contém o corpo preparado para a API de branch protection. O contexto verify corresponde ao job atual dos três serviços e da plataforma; confirmar o nome exato após o primeiro CI e ajustar se necessário. Não obrigar checks de deploy/ambiente externo em PR. CODEOWNERS não é exigido porque não foi definido neste pacote.

## Ordem de execução

Criar o repo com um README mínimo na main, aplicar a proteção, publicar código em feature/fase4-implementacao e abrir Draft PR. O bootstrap inicial é o commit necessário para existir a branch; a implementação deve entrar pelo PR. Não desativar a proteção para publicar o código.

Depois de aplicar, ler novamente a configuração e comprovar o bloqueio de push direto e merge sem aprovação/check. Manter verified_remote_protection=false até essa conferência real. A integração MCP atual não oferece escrita administrativa para aplicar essas regras; será necessário CLI autenticado com administração ou acesso permitido à interface do GitHub. Não foi criada credencial nem alterado acesso nesta preparação.

Os repos existentes não foram alterados. Qualquer correção neles deve ser tratada separadamente; a solicitação atual exige o padrão nos novos.
