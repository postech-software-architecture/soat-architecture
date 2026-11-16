# BDD completo executado

[Workflow aprovado](https://github.com/postech-software-architecture/workshop-infra-platform/actions/runs/43780849850), versão do executor 3e7b8d4faa0a86a7d5ad24cb0db36b51c9bdc8b6: **1 cenário/5 passos, zero falhas/erros/skips, dry-run=false**, concluído em 15/11/2026 às 21:33:36 BRT. Duração JUnit 109,795 s, incluindo espera pela compra.

O cenário abriu a OS 11 com idempotência, diagnosticou, rejeitou/recompôs proposta, conferiu estoque, aprovou, bloqueou reparo sem pagamento, aguardou compra real de teste e concluiu reparo/entrega da mesma OS/tentativa/trabalho. Mercado Pago foi consultado por recurso, vendedor test_user, aplicação, referência, R$ 286,25 e BRL.

- [Resumo](evidencias/bdd/resumo.json), [Cucumber JSON](evidencias/bdd/cucumber.json), [JUnit](evidencias/bdd/junit.xml), [imagens implantadas](evidencias/bdd/runtime-versions.json) e [consulta independente](evidencias/bdd/verificacao-independente.json).
- O HTML completo está no artifact bdd-complete-reports do run e no pacote local SOAT4-Evidencias-BDD.zip. O artifact remoto tem retenção de 7 dias; JSON/JUnit foram preservados aqui.
- [Executor e instruções](https://github.com/postech-software-architecture/workshop-infra-platform/tree/main/integracao/bdd).

O CI bdd-contract é um dry-run de compilação/bindings e não é esta prova de aceitação. O cenário real foi assistido apenas na compra pelo aplicativo do comprador de teste; o restante foi automatizado. Não é preciso pagar de novo para consultar essa evidência.
