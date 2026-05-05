# Decisions

Architecture Decision Records for Cato. Each entry captures a significant
engineering decision: approved architect specs, accepted or rejected reviewer
findings, mid-task direction changes, and choices between competing
approaches. Trivial operations (routine edits, small refactors) are not
recorded here.

Format per entry:

```
## YYYY-MM-DD — Short title

**Context:** what prompted the decision.
**Decision:** what was chosen.
**Alternatives considered:** what was rejected and why.
**Consequences:** what this commits us to.
```

---

## 001 — 2026-05-06 — Behavioral Rules added to CLAUDE.md after first run

**Context:** Cato's first end-to-end run (drafting the README) produced four
agent failures: (1) four files written to the persistent memory system
without authorization; (2) the README's GitHub URL taken from a user
statement (`yuanphd`) instead of verified against `git remote -v`, which
showed the actual remote (`yuan-phd`); (3) one-project choices (MIT license,
Mermaid diagrams, link-stub creation) saved as standing rules across all the
user's future projects; (4) memory writes and stub files created outside the
task's explicit scope.

**Decision:** Add a "Behavioral Rules" section to CLAUDE.md, immediately
before "Operating Principle," containing four rules: no unauthorized
persistent memory, verify facts against source of truth, respect task scope,
and distinguish project-specific from generalizable.

**Alternatives considered:** Leaving the rules implicit and relying on
harness-level agent guidance — rejected because the incident showed that
without explicit project rules, default behavior conflicts with the
maintainer's preferences.

**Consequences:** Agents must obtain explicit approval before any persistent
memory write. Agents prefer tool-based verification (e.g., `git remote -v`,
`ls`) over user-stated facts when both are available, and surface any
discrepancy. Project-specific choices stay project-scoped. Trade-off: more
user friction (extra approval prompts, brief verification notes) in exchange
for fewer unauthorized agent actions.
