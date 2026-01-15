# Token Management Service

API completa para gerenciamento de tokens construída com Elixir, Phoenix, Ecto e OTP. O serviço mantém um **pool fixo de 100 tokens pré-gerados**, garante no máximo 100 ativações simultâneas, aplica expiração automática (**TTL de 2 minutos**) e política **LRU (Least Recently Used)** quando o pool chega ao limite. Todo uso é auditável via `token_events` e a concorrência é tratada apenas com processos OTP.


---

## Arquitetura

- **Clean Architecture + DDD** no bounded context `TokenManagementService.Tokens`.
- **TokenManager** (GenServer) mantém os tokens ativos, aplica LRU e TTL.
- **ExpirationScheduler** agenda/cancela timers de 2 minutos.
- **Tokens.Repo** encapsula o acesso ao banco via `Ecto.Multi`.
- **TokenController** expõe todo o domínio via HTTP/JSON.
- **PostgreSQL** armazena as tabelas `tokens` (estado atual) e `token_events` (auditoria).

---

## Tecnologias Utilizadas

- Elixir 1.16 / Erlang 26
- Phoenix 1.7 (modo API)
- Ecto + PostgreSQL
- OTP (GenServer, Supervisors)
- Req para chamadas HTTP (quando necessário)
- ExUnit para testes

---

## Regras de Negócio (resumo)

- Existem exatamente 100 tokens (UUID) pré-semeados; não são criados/removidos em runtime.
- Tokens alternam entre `available` e `active`.
- No máximo 100 tokens ativos simultaneamente.
- Cada alocação gera um `user_id` (UUID) e registra esse valor no estado e nos eventos.
- TTL de 2 minutos: após esse tempo o token é liberado automaticamente.
- Ao chegar em 100 ativos, o 101º pedido libera o token ativo mais antigo (LRU) antes de alocar.
- Histórico completo em `token_events` (`activated`, `released`, `expired`).

---

## Pré-requisitos

- Elixir/Erlang instalados
- PostgreSQL local (`postgres/postgres`)

### Configuração

```bash
git clone <repo>
cd token_management_service
mix setup            # instala dependências, cria DB e aplica seeds (100 tokens)
mix phx.server       # inicia API em http://localhost:4000
# ou iex -S mix phx.server para sessão interativa
```

### Testes

```bash
mix test
mix test --only lru   # executa apenas o cenário de LRU (101ª alocação)
```

Os testes usam o banco `token_management_service_test` via SQL Sandbox; nenhum dado de desenvolvimento é afetado.

---

## Como utilizar a API

Base URL: `http://localhost:4000/api`

| Endpoint | Descrição | Resposta |
| --- | --- | --- |
| `POST /tokens/allocate` | Aloca um token. Se 100 tokens estiverem ativos, aplica LRU. | `{"token_id": "...", "user_id": "..."}` |
| `POST /tokens/:id/release` | Libera um token ativo. | `{"ok": true}` ou `404 token_not_active` |
| `GET /tokens?status=all|available|active` | Lista tokens filtrando por status. | `{"tokens": [...]}` |
| `GET /tokens/:id` | Detalhes de um token. | `{"id": "...", "status": "...", ...}` |
| `GET /tokens/:id/events` | Histórico completo do token. | `{"token_id": "...", "events": [...]}` |
| `POST /tokens/cleanup` | Libera todos os tokens ativos. | `{"released": numero}` |

### Exemplos com `curl`

```bash
curl -X POST http://localhost:4000/api/tokens/allocate
curl "http://localhost:4000/api/tokens?status=all"
curl "http://localhost:4000/api/tokens?status=available"
curl "http://localhost:4000/api/tokens?status=active"
curl http://localhost:4000/api/tokens/<token_id>
curl http://localhost:4000/api/tokens/<token_id>/events
curl -X POST http://localhost:4000/api/tokens/<token_id>/release
curl -X POST http://localhost:4000/api/tokens/cleanup
```

Substitua `<token_id>` pelo valor retornado no endpoint de alocação.

---

## Rodando com Docker

```bash
docker compose up --build
```

Depois acesse `http://localhost:4000/api`.

Para executar comandos dentro do container:

```bash
docker compose run --rm web mix ecto.setup
docker compose run --rm web mix test
```

---

## Detalhes de Implementação

- **TokenManager (GenServer)**
  - Guarda `%{active: %{token_id => last_activated_at}}`.
  1. `allocate/1`: pega token disponível ou, se houver 100 ativos, libera o ativo mais antigo (`reason: "lru_eviction"`) e o reutiliza.
  2. Agenda expiração em 2 minutos via `ExpirationScheduler`.
  3. `release/1` cancela timer e grava evento `released`.
  4. `cleanup_active_tokens/0` libera todos os ativos (endpoint administrativo).
- **ExpirationScheduler**: armazena referências de timers; ao disparar envia `{:expire_token, token_id}` para o TokenManager.
- **Tokens.Repo**: centraliza as transações (`activate`, `release`, `expire`) e normaliza metadados sempre com `user_id`.
- **Seeds**: `priv/repo/seeds.exs` garante que existam 100 tokens `available` em qualquer ambiente.

---

## Estratégia de Testes

- `ConnCase` inicia `TokenManager` e `ExpirationScheduler` apenas nos testes que precisam (`@moduletag :token_pool`).
- Testes de controller cobrem todos os endpoints e casos de erro.
- Testes unitários (`test/token_management_service/tokens/repo_test.exs`) garantem que o adapter `Tokens.Repo` cria eventos e muda estado corretamente; `token_pool/token_manager_test.exs` valida alocação/evicção direto no GenServer.
- Teste dedicado (`@tag :lru`) prova que a 101ª alocação reaproveita o token ativo mais antigo.
- Rode testes individuais com `mix test caminho:linha` ou por tag (`mix test --only lru`).

---

## Licença

Projeto desenvolvido para o desafio técnico da Just Travel. Utilize como referência de arquitetura limpa com OTP/Phoenix.
