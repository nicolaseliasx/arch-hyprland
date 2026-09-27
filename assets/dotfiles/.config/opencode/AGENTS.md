# Tooling

Prefix shell commands with `rtk`. Use `rtk proxy <command>` only when RTK cannot pass the command through directly.

Use `rtk gh` for GitHub operations. Do not commit, push, create or modify pull requests or issues, or otherwise change remote GitHub state without the user's explicit authorization.

# >>> flow delegacao >>>
- MUST: antes de TODA chamada de subagent, anunciar em uma linha exata: `[<agente>] <modelo> — <motivo 3-6 palavras>` (ex.: `[scanner] glm-5.3-flash — localizar usos`).
- A linha de anuncio deve bater 1:1 com os argumentos reais do spawn; divergencia entre anuncio e spawn e erro auditavel no transcript.
- Apos o spawn, o pai fica em silencio: nenhum trabalho paralelo, nenhuma inspecao de worktree, nenhum comentario de progresso ate o resultado final do subagent, que deve ser encaminhado inalterado.
- Delegar apenas quando `cost(delegation) < cost(main-context-pollution)`.
# <<< flow delegacao <<<


# >>> flow approved-plan-executor >>>
- MUST: after a plan is approved and execution is requested, decide whether to keep implementation in the parent context or invoke `$approved-plan-executor`.
- MUST: invoke `$approved-plan-executor` when the user explicitly asks for a subagent, parallelism, or a weaker/cheaper model, or when the parent judges that a self-contained, bounded plan can be executed by a clean-context worker with net cost/time benefit and no material loss of quality. Keep implementation in the parent when accumulated context, unresolved investigation, implicit preferences, uncertain integration, or likely interactive debugging would make delegation harmful.
- When `$approved-plan-executor` is selected, MUST: do not materialize a plan file before approval or without concrete executable work. The executor skill writes the self-contained plan (weak-executor contract), classifies its tier (complex -> worker-complex with GLM-5.3, fast -> worker-fast with GLM-5.3-Flash), announces `[<tier>] <modelo> — <motivo>`, delegates it to exactly one clean subagent, and waits only for its final result.
# <<< flow approved-plan-executor <<<

# >>> flow context >>>
Read `$HOME/documents/workspace/workflow/configs/shared/AGENTS.md` before working. It is the canonical instruction source.
Load only the referenced playbooks and skills relevant to the current task.
Keep local task state in this worktree; maintain reusable rules in the canonical source.
# <<< flow context <<<
