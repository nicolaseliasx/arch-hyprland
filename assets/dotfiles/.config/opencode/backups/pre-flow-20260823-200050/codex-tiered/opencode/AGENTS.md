# Tooling

Prefix shell commands with `rtk`. Use `rtk proxy <command>` only when RTK cannot pass the command through directly.

Use `rtk gh` for GitHub operations. Do not commit, push, create or modify pull requests or issues, or otherwise change remote GitHub state without the user's explicit authorization.

## Navegacao em codigo com Graphify

- Em qualquer repositorio Git, antes de explorar arquitetura, dependencias, chamadores ou impacto de uma mudanca, execute `graphify-worktree status` na raiz do worktree atual. Use `graphify` como fonte primaria de contexto estrutural somente quando o resultado for `status=fresh` e `graphify-out/graph.json` existir nesse worktree.
- Use `graphify explain`, `query`, `affected` e `path` conforme a pergunta. Para descobrir conexoes independentemente do sentido da aresta, use `graphify path ... --undirected`.
- Use `rg` para busca textual ou de nomes de arquivos e como fallback quando nao houver grafo. Nao substitua uma busca literal simples por Graphify.
- Nunca consulte um grafo de outro worktree ou gere/reconstrua um grafo semanticamente automaticamente; informe quando o estado estiver `missing`, `syncing` ou `semantic-pending`. O daemon local pode atualizar apenas codigo por AST; documentos exigem atualizacao semantica explicita.

# >>> opencode-flow clarify-task >>>
- MUST: use `$clarify-task` for explicit requests to plan, analyze an issue, define a solution, or compare alternatives.
- MUST NOT: use `$clarify-task` for direct implementation, explanation, status, or review requests.
- NEVER run `git commit` or `git push`, or create, update, merge, close, or publish anything on GitHub, unless the user explicitly authorizes that exact action in the current conversation.
- Requests to implement, execute, finish, fix, review, or ship authorize only local file changes and tests; they do not authorize commits, pushes, PR changes, comments, reviews, merges, releases, or other remote writes.
- Treat each authorization as single-use and limited to the named repository, PR or issue, content, and action. If authorization is absent or ambiguous, show the intended action or content and wait.
# <<< opencode-flow clarify-task <<<

# >>> opencode-flow approved-plan-executor >>>
- MUST: after a plan is approved and execution is requested, use `$approved-plan-executor` instead of implementing in the parent conversation.
- MUST: do not materialize a plan file before approval. The executor skill writes the approved plan, classifies its tier (complex -> worker-complex with GLM-5.3, fast -> worker-fast with GLM-5-Turbo), delegates it to exactly one clean subagent, and waits only for its final result.
# <<< opencode-flow approved-plan-executor <<<
