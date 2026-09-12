# ADR-004 — Contrato JWT compartilhado

- **Status:** aceita
- **Data:** 2026-09-12
- **Substitui:** contrato implicito anterior

## Contexto

Na W4, a aplicacao e a Lambda serao emissores do mesmo tipo de access token. Hoje a
aplicacao emite `sub`, `username`, `roles`, `iat` e `exp`, com algoritmo escolhido
implicitamente pela biblioteca. Sem contrato congelado, as duas implementacoes podem
divergir silenciosamente.

## Decisao

Todo access token deve usar este contrato:

| Campo | Valor ou regra |
|---|---|
| header `alg` | `HS256`, declarado explicitamente nos dois emissores |
| header `typ` | `JWT` |
| `iss` | literal `workshop-auth` |
| `aud` | literal `workshop-service` |
| `sub` | UUID do usuario |
| `username` | username persistido |
| `roles` | lista dos nomes das roles existentes |
| `jti` | UUID novo por access token |
| `iat` | instante de emissao |
| `exp` | emissao + 3600 segundos por padrao |

Os dois emissores usam a mesma chave HMAC recebida por `JWT_SECRET`, com no minimo 32 bytes,
nunca armazenada em codigo, output Terraform ou state compartilhado. O valor historico do
repositorio e considerado comprometido e nao pode ser reutilizado.

A aplicacao exige assinatura valida, `iss=workshop-auth` e `aud=workshop-service`. Ela
permanece responsavel por carregar o usuario do banco e aplicar RBAC; `roles` no token serve
ao contrato e a observabilidade, nao substitui a autoridade do banco.

Conformidade entre emissores e decidida por teste cruzado: um token criado pelo builder da
Lambda precisa ser aceito pelo `JwtTokenService` e pelo `JwtAuthenticationFilter`. Os dois
projetos usam `jjwt` 0.12.6 e HS256 explicito.

A Lambda devolve somente access token. Refresh e logout continuam exclusivos do fluxo de
usuario/senha da aplicacao.

## Alternativas rejeitadas

- algoritmo HMAC inferido pela biblioteca: permite drift sem alterar o codigo chamador;
- emissores com `iss` diferentes: obriga o consumidor a aceitar contratos distintos;
- autorizacao baseada apenas no claim `roles`: ignora bloqueio, ativacao e roles atuais do
  usuario no banco;
- segredo em Terraform output: amplia a exposicao para consumidores do remote state.

## Consequencias positivas

- contrato literal e testavel antes do paralelismo da W4;
- tokens da Lambda e da aplicacao sao intercambiaveis;
- validacao de emissor e audiencia reduz aceitacao indevida;
- RBAC e revogacao por estado do usuario continuam centralizados.

## Consequencias negativas

- tokens antigos sem `iss`/`aud` deixam de ser aceitos; a quebra e tolerada porque expiram
  em uma hora;
- rotacao do segredo exige atualizar aplicacao e Lambda na mesma janela;
- `jti` sera inicialmente apenas um identificador de rastreabilidade, sem blacklist.

## Evidencias e links

- `JwtTokenService` atual: cinco claims e algoritmo implicito, base para a mudanca da W4-B.
- `JwtAuthenticationFilter` atual: usuario e roles carregados do banco em cada request.
- [ADR-003](ADR-003-lambda-cpf-jwt.md)
- criterio da W4: teste cruzado e checkpoint 200/401/403.
