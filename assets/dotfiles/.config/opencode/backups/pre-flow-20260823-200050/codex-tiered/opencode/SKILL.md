---
name: approved-plan-executor
description: Materialize an approved implementation plan and execute it in one clean subagent with tier-matched routing. Use only after the plan is approved and an execution request.
---

# Approved plan executor

Use this skill only when a plan has been approved by the user and the user has
requested execution. Do not use it while planning, reviewing, explaining, or
executing a task that was not planned and approved in the current conversation.

## Parent workflow

1. Create `.opencode/plans/<YYYYMMDD-HHMMSS>-<slug>/PLAN.md` in the current Git
   repository. Do not overwrite an existing plan or create `latest.txt`.
2. Make the file self-contained for a clean executor: objective, repository
   facts, scope and exclusions, ordered implementation work, public contracts,
   failure handling, exact validation commands, and acceptance criteria.
3. Classify the plan into exactly one tier:
   - `complex` — multi-file changes, new architecture or contracts, subtle
     behavior, cross-cutting concerns, high ambiguity in integration, or any
     chance of discoverable unknowns.
   - `fast` — monotonous, well-defined work: repetitive edits, mechanical
     refactor, CRUD, config tweaks, single-pattern changes with clear specs.
   When in doubt, choose `complex`.
4. Spawn exactly one subagent via the Task tool with a clean context:
   `worker-complex` for the `complex` tier, `worker-fast` for the `fast` tier.
   Give it only the absolute plan path and the execution instruction below.
5. Wait exclusively for the child's final result. Do not inspect the worktree,
   query the subagent, request progress, emit progress updates, or synthesize
   its result while it runs.
6. Forward the child's final response unchanged. If the user cancels while
   waiting, report that the execution was cancelled.

## Executor instruction

Tell the child:

> Read the approved plan at the supplied path and the applicable `AGENTS.md`
> files. Implement only that plan in the current worktree. Run its stated
> validation commands. Do not delegate, commit, push, or make remote writes.
> If a material ambiguity, required external input, or unrecoverable validation
> failure prevents completion, stop and return a concise blocked report. End
> with a concise final result listing changed behavior and validation outcome.

The parent must not repair, retry, review, or otherwise continue after the
child finishes. A blocked or failed child result is the final result.
