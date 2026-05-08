# Decisions

Architecture Decision Records for Cato. Each entry captures a significant
engineering decision: approved architect specs, accepted or rejected reviewer
findings, mid-task direction changes, and choices between competing
approaches. Trivial operations (routine edits, small refactors) are not
recorded here.

Format per entry:

```
## ADR XXX: Short title

**Status**: [Accepted | Superseded | Rejected]
**Context**: [What's the issue or situation that triggered this decision?]
**Decision**: [What was decided?]
**Consequences**: [What does this decision mean for the project?]
```

---

## ADR 001: Behavioral Rules added to CLAUDE.md after first run

**Status**: Accepted

**Context**: Cato's first end-to-end run (drafting the README) produced four
agent failures: (1) four files written to the persistent memory system
without authorization; (2) the README's GitHub URL taken from a user
statement (`yuanphd`) instead of verified against `git remote -v`, which
showed the actual remote (`yuan-phd`); (3) one-project choices (MIT license,
Mermaid diagrams, link-stub creation) saved as standing rules across all the
user's future projects; (4) memory writes and stub files created outside the
task's explicit scope. The alternative—leaving rules implicit and relying on
harness-level agent guidance—was rejected because the incident showed that
without explicit project rules, default behavior conflicts with the
maintainer's preferences.

**Decision**: Add a "Behavioral Rules" section to CLAUDE.md, immediately
before "Operating Principle," containing four rules: no unauthorized
persistent memory, verify facts against source of truth, respect task scope,
and distinguish project-specific from generalizable.

**Consequences**: Agents must obtain explicit approval before any persistent
memory write. Agents prefer tool-based verification (e.g., `git remote -v`,
`ls`) over user-stated facts when both are available, and surface any
discrepancy. Project-specific choices stay project-scoped. Trade-off: more
user friction (extra approval prompts, brief verification notes) in exchange
for fewer unauthorized agent actions.

---

## ADR 002: Architect operates in three modes within one agent

**Status**: Accepted

**Context**: The architect role evolved beyond producing specifications. After the engineer agent landed, the architect needed to verify implementations against specs (compliance check). After the reviewer landed, the architect needed to triage reviewer findings and coordinate fixes (coordination). The question was whether to split these into separate agents or keep them as modes of one agent.

**Decision**: One architect agent with three explicit modes—Design (Mode 1), Compliance Check (Mode 2), Coordination (Mode 3). Each mode has its own input expectations and output structure. The architect identifies which mode it's operating in based on the request.

**Consequences**: Architect.md became larger (~400 lines) since it carries three role descriptions and three output structures. Offsetting this, the workflow has fewer agents to maintain and the same role consistently owns design intent across the lifecycle of a change. Splitting into multiple agents would have created naming and routing complexity for marginal benefit.

---

## ADR 003: Hub-and-spoke information flow with architect as central coordinator

**Status**: Accepted

**Context**: With three agents (architect, engineer, reviewer) plus the user, there are six possible communication pairs. Allowing free communication between any pair would let context leak between roles—engineer could be persuaded by reviewer's reasoning, reviewer could be biased by engineer's intent, user could be flooded with internal coordination noise.

**Decision**: All cross-role information flows through the architect. Engineer reports only to architect (not user, not reviewer). Reviewer reports only to architect (not engineer, not user). User communicates only with architect (via main session). Architect is the central hub.

**Consequences**: Each role operates in its own context with strict boundaries. The architect's coordination mode (Mode 3) becomes responsible for translating between roles—e.g., explaining to the user what the reviewer flagged, or routing reviewer findings to engineer dispatch. This adds work to the architect but preserves the independence each role needs.

---

## ADR 004: Reviewer sees the architect's spec (human-team review pattern)

**Status**: Accepted

**Context**: A core design question for the reviewer was how isolated its context should be. Three options surfaced: (A) reviewer sees the spec, mirroring senior PR review in human teams; (B) reviewer sees nothing but code, achieving extreme builder-validator independence; (C) reviewer sees only a high-level goal description but not the full spec.

**Decision**: Option A—reviewer receives the architect's specification (including Concerns to verify), the git diff, and test results. Reviewer does not see the architect-engineer compliance check rounds, engineer's reasoning, or any internal dialogue.

**Consequences**: Reviewer can identify implementation-vs-spec mismatches efficiently and asks targeted questions when uncertain. False positives are reduced. Trade-off: reviewer is somewhat anchored by the architect's framing of the problem, losing some of the adversarial value of pure independence. Mitigated by reviewer's explicit Question tier for cases where it's unsure if a behavior is intentional.

---

## ADR 005: Adopt Google's eng-practices for reviewer and author roles

**Status**: Accepted

**Context**: Designing the reviewer's working framework and the engineer's reporting style from scratch risked inventing conventions less tested than existing industry standards. Google's eng-practices documentation covers code review and CL authoring with proven patterns from large-scale software development.

**Decision**: Reviewer adopts Four-Pass framework (Context → Design → Implementation → Polish), five-tier findings (Blocking / Important / Nit / Question / Praise), and Code Health Standard ("approve if it improves the system, even if not perfect"). Engineer adopts CL description format (imperative subject line, what/why body), "solve the problem you have, not the one you might have," data-over-preference for pushback, and ~400-line CL size self-check. Architect adopts code owner role, attention-set discipline (every output ends with "ball is in X's court"), and anti-deadlock responsibility (escalate when loops fail to converge).

**Consequences**: Cato's agent prompts encode well-tested human practices rather than novel conventions. Reviewers and engineers in human teams behave this way for good reasons; transferring those reasons to the AI agents grounds Cato in established engineering culture. The trade-off is that some practices may not transfer cleanly to AI agents—future iterations may need adjustment based on observed behavior.

---

## ADR 006: Five-category triage scheme for Mode 3 coordination

**Status**: Accepted

**Context**: When the architect receives reviewer findings in Mode 3, each finding needs classification before action. An initial four-category scheme (must-fix / user-decision / spec-required / out-of-scope) lacked an explicit place for cases where the architect believes the reviewer is mistaken. Without it, the architect would either silently accept questionable findings or have to escalate every disagreement to user-decision.

**Decision**: Five categories: (1) Real issue—must fix (engineer dispatch); (2) Real issue—user decision (escalate); (3) Spec-required behavior (explain why it isn't a bug); (4) Out of scope (note for future); (5) Disagreed with reviewer (state reasoning, user can override).

**Consequences**: The architect has a defined channel for principled disagreement with the reviewer. The user becomes the final authority on disputes. This preserves reviewer authority for genuine issues while preventing wrong findings from forcing engineer rework. Decision Logging in CLAUDE.md captures these triage classifications as part of the project's design history.

---

## ADR 007: Engineer never commits; architect proposes, user approves

**Status**: Accepted

**Context**: Engineer authority over commits would let implementation work become permanent without explicit approval at the workflow level. This conflicts with Cato's principle that the user is the final authority on what enters the codebase.

**Decision**: Engineer never commits autonomously. After completion and reviewer review, the architect produces a commit message proposal in Mode 3 Section 4 (Final Report). The user approves, amends, or rejects the proposal. The main session executes the commit per user instruction.

**Consequences**: Commits in Cato projects always have explicit user approval. Commit messages are written with full context (architect coordinates everything that happened—spec, implementation, review findings, resolutions—into a coherent narrative). The trade-off is one extra approval step in the workflow; this is intentional and aligns with the user-as-authority principle.

---

## ADR 008: Model strategy—Sonnet for engineer, Opus for architect and reviewer

**Status**: Accepted

**Context**: Each agent's prompt specifies a Claude model. Two questions: which model fits each role, and whether to pin specific versions or track latest.

**Decision**: Engineer uses `sonnet`, architect and reviewer use `opus`. All three use generic names rather than version-pinned identifiers (e.g., `sonnet`, not `claude-sonnet-4-6`). Cato auto-tracks the latest version of each tier as Anthropic releases new models.

**Consequences**: Engineer's narrow execution role (translate spec into code) doesn't require Opus-level reasoning, saving cost and matching the role's design philosophy ("don't think, implement"). Architect and reviewer need stronger judgment for design decisions and finding severity. Generic naming means Cato benefits automatically from model upgrades; trade-off is unexpected behavior changes when Anthropic releases new models with different defaults.

---

## ADR 009: Disable Claude attribution in commit metadata

**Status**: Accepted

**Context**: Claude Code by default appends `Co-Authored-By: Claude` and "Generated with Claude Code" trailers to commit messages. For a solo portfolio project, this caused GitHub to display Claude as a contributor at the same level as the project owner, misrepresenting authorship of architectural and design decisions.

**Decision**: Set `attribution.commit: ""` and `attribution.pr: ""` in user-level `~/.claude/settings.json`. AI involvement is acknowledged transparently in the README rather than embedded in git metadata.

**Consequences**: All Cato commits appear authored solely by yuan-phd. The repository's contributors graph reflects the author's design ownership accurately. Future projects under the same user-level config also benefit. Acknowledgment of AI assistance moves to README/DECISIONS.md, where context can explain the nature of the collaboration.

---

## ADR 010: Defer the engineer-source-isolation rule until real bootstrap data exists

**Status**: Accepted

**Context**: A potential rule was considered—"engineer never creates source files inside the cato repository's working tree, except for Cato's own self-development files." The intent was to prevent Cato from being used to generate unrelated project code that would pollute its own git history. However, the rule had a logical hole: Cato's CLAUDE.md is part of the configuration that would be copied to bootstrap new projects, so a rule referencing "this repository" would either be incorrectly inherited or would need a complex template-vs-instance separation.

**Decision**: Do not add the self-protection rule to CLAUDE.md now. When Cato is first used to generate a separate project, design the bootstrap mechanism (likely a CLAUDE.md template separated from cato-specific content), and at that point decide where self-protection lives.

**Consequences**: For now, the user and main session must rely on explicit instructions ("write the code to ~/work/portfolio/X/") to keep produced code outside cato/. This is a minor risk during the first end-to-end workflow test; it becomes a real concern only once Cato is used productively. Postponing the rule avoids encoding a flawed design and waits for real usage data to inform it.

---

## ADR 011: Telegram as the mobile notification channel

**Status**: Accepted

**Context**: Cato benefits from a mobile channel for status updates and quick decisions when the user is away from the terminal. Candidate channels included Telegram, Discord, iMessage/SMS, email, and Slack.

**Decision**: Telegram via the official Claude Code plugin (`telegram@claude-plugins-official`). A dedicated bot (`@yuanphd_cato_bot`) handles bidirectional communication with an allowlisted user.

**Consequences**: Cross-platform availability (iOS, Android, web), mature bot ecosystem, no vendor lock-in (Telegram bots are first-class API citizens), and an established convention among personal AI assistants. Anthropic's native push notifications had reliability issues on iOS during setup, making the Telegram plugin more dependable. Trade-off: relies on Telegram remaining a viable platform; not a concern in the foreseeable future.

---

## ADR 012: Path A (Claude Code subagents) over Path B (Python orchestrator + LangGraph)

**Status**: Accepted

**Context**: Two architectures were considered for Cato's multi-agent coordination: (A) use Claude Code's built-in subagent mechanism, with each agent defined in a markdown file under `.claude/agents/`; (B) build a Python orchestrator using LangGraph or similar, calling the Anthropic API directly.

**Decision**: Path A. Cato is implemented entirely as Claude Code subagent definitions plus the project's CLAUDE.md as orchestrator context.

**Consequences**: Subscription-friendly—Claude Max covers all usage with no per-token billing. No infrastructure to maintain (no Python service, no API key management, no error handling for transient failures). Trade-off: less control over the orchestration logic; tied to Claude Code's evolution. Path B remains a possible v2 direction if Cato outgrows the subagent model—e.g., for multi-vendor reviewers or long-running asynchronous workflows.

---

## ADR 013: Anti-over-engineering as a design discipline for agent prompts

**Status**: Accepted

**Context**: Each subagent's prompt is loaded fresh on every invocation. A long workflow can invoke an agent multiple times (e.g., compliance loop iterations, reviewer dispatch loops). Long prompts compound token cost and dilute attention. An earlier draft of engineer.md ran to ~290 lines; the committed version is ~110 lines, achieved by removing redundant restatements without losing functional rules.

**Decision**: Agent prompts are kept as compact as possible while preserving every functional rule. Verbosity is removed; redundant restatements across sections are merged. New rules are added based on observed need, not preventive specification. Architect.md (currently ~400 lines) is left unsimplified for now—decision deferred until real workflow data shows which rules matter.

**Consequences**: Per-invocation token cost stays manageable. Rules are discoverable rather than buried in prose. The trade-off is that agent prompts feel terse; some context that would help a first-time human reader is omitted because the agent doesn't need it. This trade-off favors agent runtime efficiency over human readability of the agent definition.

---

## ADR 014: Cato deployment model—per-project copy, not user-level install

**Status**: Accepted

**Context**: Cato's agent definitions and workflow rules need to be available to Claude Code when working on a project. Two deployment models were considered: (1) install Cato into `~/.claude/` (user-level, applies to all projects automatically), or (2) copy Cato's contents into each project that uses it. Option 1 was initially attractive for its automatic propagation, but conflicts with several principles: it pollutes the user-level Claude Code namespace that other agents and tools also need to share; it makes projects non-self-contained (behavior depends on user-level state); it changes project behavior implicitly when Cato is upgraded; and it forces all Claude Code work—including non-Cato tasks—to load Cato workflow rules.

**Decision**: Cato is deployed per-project. Each project that wants to use Cato gets its own copy of `.claude/agents/` and a CLAUDE.md that includes Cato workflow rules. The user-level `~/.claude/` directory is kept free of Cato-specific content to remain available for other agents and tools.

**Consequences**: Projects are self-contained—the project repository includes everything needed for Cato to work. Behavior is explicit and visible in the project's file structure. Cato versions can be pinned per-project (a project keeps the Cato version it was bootstrapped with until explicitly upgraded). Cato upgrades require manual sync to existing projects, but Cato's intentional stability (see ADR 015) keeps this overhead low. The `~/.claude/` namespace remains available for unrelated agents, tools, or future Cato extensions that genuinely need user-level scope.

---

## ADR 015: Cato's body remains stable; project-specific learnings are not absorbed

**Status**: Accepted

**Context**: Each project produces learnings—patterns observed, friction encountered, mistakes recognized. A natural impulse is to absorb these learnings into Cato's body (agents, CLAUDE.md) so future projects benefit. However, project learnings are often domain-specific: a Web API convention does not apply to a CLI tool; a string-processing edge case does not generalize to numerical computation. Absorbing project-specific learnings into Cato's body would pollute the body with rules that are wrong outside their original context, causing bugs in unrelated projects.

**Decision**: Cato's body—agent definitions, workflow rules, Behavioral Rules—contains only genuinely universal engineering principles. Project-specific patterns and conventions are documented at the project level, not absorbed into Cato's body. Cato's body changes are deliberate and rare, justified by ADR.

**Consequences**: Cato's body stays small, pure, and trustworthy across all projects that use it. Absorbing learnings into Cato becomes a deliberate decision (write an ADR, modify body) rather than accidental drift. The trade-off is that project-specific learnings do not automatically propagate—each project decides its own conventions in its own CLAUDE.md. This is by design: cross-project propagation requires conscious user judgment about what is universal vs. context-specific.

---

## ADR 016: Retrospectives belong to projects, not to Cato's body

**Status**: Accepted

**Context**: If a retrospective is written for a workflow run, it documents what was learned during the work—friction points, observations about agent behavior, candidate patterns for future consideration. The question is where retrospectives live: inside each project, in a global Cato-owned location, or somewhere else entirely. Storing retrospectives in Cato's body or in a Cato-adjacent global location risks polluting Cato (per ADR 015) and creates ambiguous ownership. Retrospectives are about a specific project's work—their natural owner is the project itself.

**Decision**: Each project's retrospective lives inside the project as `retrospective.md`. The file is git-tracked and pushed alongside the rest of the project's content. Cross-project review of retrospectives is a manual, low-frequency activity—the user navigates project repositories to read retrospectives when reflecting on patterns.

**Consequences**: Retrospectives are naturally scoped to the project that produced them. Git provides version control and persistence. Project repositories stay self-contained—a project's retrospective travels with the project. Cross-project synthesis requires user effort (cd into multiple repos, read retrospectives, identify common patterns), but this is a low-frequency activity and the friction is acceptable. Retrospectives written publicly may demonstrate engineering reflection skills in a portfolio context, an unintended but useful side effect.

---

## ADR 017: Retrospective generation as a skill, not a new agent

**Status**: Superseded by ADR 018

**Supersession note**: After further reflection, the retrospective system is not built. See ADR 018 for reasoning.

**Context**: Generating a retrospective at the end of a workflow involves collecting metrics (spec length, compliance loop iterations, finding distributions, commit hash) and prompting the user to add subjective reflection. This is a procedural workflow with no independent judgment—it does not warrant the overhead of a new agent. Two implementation options were considered: extend an existing agent (e.g., have the architect produce retrospectives in Mode 3 final report) or use Claude Code's skill mechanism. Extending an agent violates Cato's "narrow role" principle. Skills are the appropriate mechanism for lightweight workflow templates that the main session executes directly.

**Decision**: Retrospective generation will be implemented as a Claude Code skill (`cato-retrospective`) located in the project's `.claude/skills/` directory. The skill instructs the main session to collect metrics from the just-completed workflow, generate a retrospective draft in the project's `retrospective.md`, and prompt the user to fill in subjective reflection sections. The skill produces only retrospectives—it does not generate new skills or new agent rules.

**Consequences**: No new agent is added; existing agents keep their narrow roles. The skill is lightweight and lives in each project's local `.claude/skills/`, consistent with the per-project deployment model (ADR 014). Retrospective output is text in `retrospective.md`, never code or new tools—this prevents skill-generated artifacts from accidentally becoming part of Cato's body (preserving ADR 015).

---

## ADR 018: Drop the retrospective system; rely on organic reflection

**Status**: Accepted

**Context**: ADR 017 planned a `cato-retrospective` skill to automate retrospective generation after each workflow run. On further reflection, the value of structured retrospectives became uncertain. The mechanism for who captures "decisions made"—main session memory, agents writing their own decision logs, or user discipline—did not have an obviously correct answer. More fundamentally, the value of accumulated retrospectives is unclear: a retrospective written by obligation (because the skill triggered) is likely to produce formulaic content ("nothing notable this time"), which is worse than no retrospective at all.

**Decision**: Do not build the `cato-retrospective` skill. Do not modify agents to log decisions. Reflection happens organically—when something during a workflow genuinely prompts the user to stop and think, they write that thought somewhere of their choosing (project markdown, personal notes, anywhere). When a thought rises to the level of a universal pattern worth changing Cato's body, it goes through the standard ADR process directly, without an intermediate retrospective.

**Consequences**: No automated retrospective infrastructure. No agent changes for decision logging. Reflection is need-driven, not schedule-driven, which keeps reflection authentic when it happens. The trade-off is that subtle observations may be lost if the user does not pause to write them down—this is an accepted cost. The ADR pipeline (genuinely universal pattern → ADR → Cato body change) remains the only path for reflection to affect Cato itself.

---

## ADR 019: First end-to-end Cato run — reverse(s) workflow-validation

**Status**: Accepted

**Context**: With all three agents (architect, engineer, reviewer) implemented, Cato needed a real workflow run to validate that the full loop (architect Mode 1 → engineer → architect Mode 2 → reviewer → architect Mode 3) operates as the constitution describes. The chosen target was a Python `reverse(s)` function with grapheme-cluster-aware Unicode handling, implemented under a gitignored `test-run-1/` directory.

**Decision**: Run the full workflow on `reverse(s)`. Commit only the review archive (`reviews/review-20260507-001.md`) and this ADR; leave the implementation files in `test-run-1/` (gitignored). Triage decisions:

- Reviewer Nits 1 and 2 (raw NFD/ZWJ literals vs. escape form): out-of-scope (note for future). Spec language was advisory; case 20 is a runtime canary against NFC contamination; file is byte-correct.
- Reviewer Nit 3 (requirements.txt comment style): disagreed-with-reviewer. Existing comment is grammatical and clear; suggested form is no clearer.
- No Blocking, no Important, no Questions, no engineer dispatch.

**Consequences**: Confirms the full Cato loop functions end-to-end on a non-trivial target. The run also surfaced a structural issue with how the main session forwards information to sub-agents; that finding is recorded separately in a follow-up ADR rather than embedded here.

---

## ADR 020: Inter-agent communication through files; main session does not paraphrase

**Status**: Accepted

**Context**: The first end-to-end Cato run (ADR 019) revealed a structural problem: the main session, when forwarding information between sub-agents, paraphrased and occasionally hallucinated file content. In one instance the main session misquoted `requirements.txt` content and incorrectly accused the reviewer of hallucinating—the reviewer's quote was accurate. This is not a discipline issue; it is a structural one. The main session is an LLM, and when it summarizes content for the next sub-agent's prompt, it generates rather than copies—which means it can change content. Cato's design implicitly assumed the main session was a trustworthy router; that assumption is wrong.

**Decision**: Inter-agent communication uses files, not main-session prompts. Each agent writes its output to a fixed path under `.cato/state/`; the next agent reads that file directly. The main session's role is reduced to mechanical dispatch—it triggers the next agent and references file paths, but does not paste, summarize, or quote content from prior agents or source files in the dispatch prompt. Specifically:

- `.cato/state/spec.md` — architect Mode 1 output
- `.cato/state/engineer-completion.md` — engineer's completion report
- `.cato/state/compliance-check.md` — architect Mode 2 output
- `reviews/review-YYYYMMDD-NNN.md` — reviewer findings (already in this location per existing convention)
- `.cato/state/coordination-report.md` — architect Mode 3 output

When dispatching a sub-agent, the main session passes file paths only. The sub-agent uses its `Read` tool to access the content itself.

**Consequences**: Eliminates the main-session-as-untrusted-forwarder failure mode—the main session has no opportunity to paraphrase content that doesn't pass through its prompt. Provides a natural audit trail (`.cato/state/` shows the exact handoff content for each step). Survives Claude Code session restarts: state lives in files, so an architect sub-agent invoked in a later session can pick up where the previous one left off. Trade-off: each sub-agent makes one or two extra `Read` tool calls per invocation. `.cato/state/` requires lifecycle management (cleared at workflow start, or retained as audit history—to be decided when implementing). Implementation deferred to a follow-up commit.

---

## ADR 021: Architect gets Write access, scoped to .cato/state/run-N/

**Status**: Accepted

**Context**: ADR 020 introduced file-based inter-agent communication: each agent writes its output to a fixed path under `.cato/state/run-N/`. However, architect.md explicitly denies the architect Write, Edit, and Bash tools. The original rationale was to prevent the architect from drifting into implementation. The two requirements conflict: ADR 020 requires the architect to write its own outputs (spec.md, compliance-check.md, coordination-report.md), but the tool denial prevents it from doing so. The first run-2 attempt exposed this directly—the architect produced a spec correctly but had no way to persist it, forcing the main session to write the file on the architect's behalf. That workaround reintroduces the main-session-as-middleman failure mode that ADR 020 was designed to eliminate.

**Decision**: The architect is granted the Write tool, with the understanding that its writes are restricted to `.cato/state/run-N/` paths. The architect uses Write for its own structured outputs (spec.md, compliance-check.md, coordination-report.md) and nothing else. The architect still has no Edit or Bash tools—it cannot modify code or execute it. The "architect does not implement" principle is preserved: the rule was always about not writing code, not about being unable to persist its own deliverables.

**Consequences**: Resolves the contradiction between ADR 020 and architect.md. The architect can fulfill the file-based protocol without main-session intervention. The "no implementation drift" guarantee remains intact through the absence of Edit and Bash, and through the implicit scope restriction on Write (architect.md will document this restriction). Path enforcement is by convention in the agent definition, not by tool-level restriction—Claude Code does not natively support per-tool path scoping, so the constraint is documented and trusted at the agent level. If the architect ever writes outside `.cato/state/run-N/`, that is a violation to be caught and fixed; not a structural prevention.
