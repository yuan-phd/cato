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

---

## ADR 022: Main session is a mechanical dispatcher; no file reads, no workflow judgments

**Status**: Accepted

**Context**: Run-2 surfaced two recurring main session behaviors that violate the spirit of ADR 020 (main session as untrusted forwarder). First, when asked to display file contents to the user, the main session repeatedly used the Read tool instead of `bash + cat`. The Read tool loads file content into the main session's context but does not echo it to the user, so the user sees only "Read 1 file" while the main session has the content. This recreates the hallucination surface ADR 020 was designed to eliminate—content flows through the main session's LLM rather than being shown raw to the user. Second, the main session repeatedly proposed workflow judgments to the user (e.g., "Three options for resuming: a/b/c, my recommendation is b"). Workflow triage and recommendations are the architect's job (Mode 3 coordination); the main session asserting its own recommendations means it is reasoning about workflow state rather than mechanically executing the next dispatch.

Both behaviors share a root cause: the main session implicitly treats itself as a participant in the workflow (analyzing, recommending, paraphrasing) rather than as a mechanical dispatcher. ADR 020 reduced its content-forwarding role; ADR 022 extends the constraint to file reads and judgments.

**Decision**: The main session is a mechanical dispatcher. Two operational rules:

1. **No Read of project files**. The main session does not use the Read tool on files within the project (including `.cato/state/run-N/`, `reviews/`, source files, and configuration files). When the user asks to see a file's contents, the main session uses `bash` with `cat` (or `head`, `tail`, `grep` as appropriate) and pastes the raw stdout. When a sub-agent needs file content, the sub-agent reads it directly per ADR 020. The main session has no legitimate reason to load project file content into its own LLM context. Exception: bash commands that operate on git (`git log`, `git status`, `git diff`) are permitted because the user expects shell-style output.

2. **No workflow judgments**. The main session does not propose options, recommendations, or triage decisions about the workflow itself. Workflow triage is the architect's responsibility (Mode 3). When the workflow encounters an unexpected state, the main session surfaces the situation factually to the architect (or to the user if the architect cannot be reached), but does not author its own option lists or recommendations. The main session's outputs to the user are: (a) raw file contents when requested, (b) sub-agent return messages verbatim, (c) tool execution results, and (d) factual status updates ("dispatched architect", "engineer reported completion"). Not: option menus, "my recommendation is", or analysis of what should happen next.

**Consequences**: Closes the file-content side channel that bypassed ADR 020. Restores Mode 3 as the sole authority for workflow triage. The main session becomes simpler: dispatch the next sub-agent per the prior agent's stated next step, surface raw outputs, and wait. If the architect's coordination report fails to specify a next step, the main session reports the gap factually rather than improvising. The trade-off is reduced helpfulness in edge cases where the main session might have offered a useful suggestion—accepted as the cost of structural integrity. Implementation: update CLAUDE.md to document both rules under Workflow Rules. Sub-agent definitions are unaffected.

---

## ADR 023: Mode 3 Must Verify Factual Claims About External State

**Date**: 2026-05-10
**Status**: Accepted

### Context

Run-3 (slugify) surfaced a Mode 3 failure mode that on inspection
turned out to be a recurrence of a run-1 failure, not a new one:

- Run-1: architect proposed ADR 018 in coordination-report.md when ADR
  018 already existed. Cause: it asserted the next number from memory
  instead of grepping DECISIONS.md. Patched narrowly by adding a "grep
  before proposing an ADR" rule to architect.md (the original Rule A).

- Run-3: architect's coordination-report.md §4 claimed test-run-1/ and
  test-run-2/ contents had been "committed via git add -f" as an
  established precedent, and proposed the same for test-run-3/. The
  claim was fabricated — those directories are gitignored and their
  contents have never been committed. The proposal also internally
  contradicted the spec's own setup step (which added test-run-3/ to
  .gitignore).

Both failures share one shape: architect made a factual claim about
state outside its current working memory (DECISIONS.md contents in
run-1; git history and prior-run conventions in run-3) by recall, when
verification with an available tool was cheap. The narrow run-1 patch
covered ADR numbers and nothing else, so the same failure shape
recurred in run-3 against a different external surface.

### Decision

Generalize the run-1 patch. In Mode 3, any factual claim in
coordination-report.md that references state outside the architect's
immediate run context must be verified with a tool call before being
written. The original ADR-number rule becomes a specific instance of
this general rule.

In-scope external surfaces and their verification routes (architect
has Read, Grep, Glob, WebSearch, WebFetch, Write — no Bash):

- **Git history / index** — Read `.git/logs/HEAD`, Grep `.git/index`,
  or read commit objects under `.git/objects/`. Architect cannot run
  `git` commands directly; if the needed verification exceeds tool
  scope, escalate to user.
- **DECISIONS.md / ADR contents** — Read or Grep DECISIONS.md.
  Includes the next-ADR-number procedure (grep `^## ADR`, skip
  template line, take highest + 1).
- **Prior-run conventions** — Read the relevant files under that
  run's directory or `.cato/state/run-N/`.
- **File contents outside the current run** — Read the file.

Mode 3 must also do an internal-consistency self-read of
coordination-report.md before finalizing: do any two claims contradict
each other, or contradict this run's spec? Run-3's `git add -f` proposal
contradicted the spec's own gitignore setup step; one self-read pass
would have caught it.

When verification is impossible within architect's tool scope, the
honest move is to state the gap explicitly ("I cannot verify X with
available tools; escalating to user") and escalate. Fabricated facts
in a coordination report are a worse failure than an honest gap,
because user approval downstream depends on the report being trustworthy.

### Consequences

- architect.md Mode 3 setup section replaces the narrow ADR-number
  rule with the general external-state verification rule. The
  ADR-number procedure is preserved as a specific instance.
- Coordination reports become slightly longer when verification gaps
  must be acknowledged. This is acceptable: an explicit gap is
  cheaper than a fabricated claim discovered downstream.
- Behavioral Rule 2 in CLAUDE.md ("Verify facts against source of
  truth") remains the abstract principle; this ADR is its concrete
  Mode 3 specialization, in the same spirit as ADR 022 specializing
  it for the main session.
- The run-1 narrow rule is not removed; it is generalized. No prior
  ADR is superseded.

### Notes

The pattern — a narrow rule patched for one failure surface, the same
failure shape reappearing on a different surface — is itself worth
remembering. Future patches that target one specific symptom should
ask whether the underlying shape is wider; a one-paragraph
generalization at first patch time is cheaper than a second-occurrence
post-mortem.

---

## ADR 024: Mode 2 Must Escalate Spec Inconsistency, Not Silently Correct It

**Date**: 2026-05-12
**Status**: Accepted

### Context

Run-4 (`is_palindrome`) surfaced a Mode 2 failure mode that, on
inspection, is part of a recurring pattern across runs:

- Run-1: architect proposed an ADR number from memory (ADR 018 when
  ADR 018 already existed) instead of grepping DECISIONS.md.
  Patched narrowly; later generalized in ADR 023.
- Run-3: architect's coordination-report.md §4 claimed an established
  `git add -f` precedent that did not exist. Fabricated factual claim
  about external state. Addressed by ADR 023.
- Run-4: architect, during Mode 2 round-1 compliance check, discovered
  the spec's §4 "Palindrome rules" table and case-29 expected output
  were internally inconsistent with the spec's §4 algorithm. The
  architect silently corrected the spec (overwriting the user-approved
  expected output from `False` to `True`) and issued a `NEEDS REVISION`
  to the engineer based on the corrected expectation, without
  consulting the user. The reviewer caught this in run-4's review and
  flagged it as a Question for Mode 3 triage.

The three failures share one shape: the architect made a decision it
should have escalated. ADR 023 covered the factual-claim side of this
shape (claims about external state must be verified, not recalled).
This ADR covers the workflow-decision side: when Mode 2 discovers that
the spec itself is wrong (not just that the implementation diverges
from it), the spec is the user's approved artifact, and changing it
is the user's call, not the architect's.

The silent-correction failure is structurally worse than a fabricated
fact because (a) it changes the contract the user approved, (b) it
hides the change inside a `NEEDS REVISION` directive against the
engineer, who has no signal that the spec itself was the source of
the gap, and (c) downstream artifacts (test comments, commit messages,
reviewer's read of the spec) inherit a corrected expected behavior
the user never agreed to. In run-4 the divergence was caught because
the reviewer is isolated from the compliance-check transcript and can
re-derive the spec's algorithm independently; without that
independence, the silent correction would have shipped without notice.

### Decision

In Mode 2, when the architect discovers that the spec is internally
inconsistent, factually incorrect, or in conflict with itself (as
distinct from finding that the implementation diverges from the
spec), the architect must escalate to the user before any spec edit.
The architect must not unilaterally rewrite spec content the user
approved, and must not issue a `NEEDS REVISION` to the engineer based
on a spec interpretation the user has not seen.

Concretely, when Mode 2 finds a spec inconsistency:

1. Stop the compliance-check loop on the affected item.
2. Write a Mode 2 verdict of `FAIL` (not `NEEDS REVISION`) with the
   inconsistency clearly described: which spec sections conflict, the
   two possible interpretations, and what the architect would
   recommend. `FAIL` is the appropriate status because the spec — not
   the implementation — is the artifact that needs revision.
3. The main session surfaces the `FAIL` to the user. The user
   resolves the inconsistency by approving an amended spec, a
   documented exception, or a different direction.
4. Only after the user's resolution does Mode 2 reopen and continue
   the compliance check against the resolved spec.

When Mode 2 finds a smaller-scale issue — e.g., a typo in a spec
example that doesn't change behavior — the architect may flag the
typo to the user without halting the run, but still must not silently
correct it. The user owns the spec.

This ADR is the workflow-decision counterpart to ADR 023's
factual-claim rule. Together they cover the broader pattern: the
architect must surface gaps, not absorb them.

### Consequences

- architect.md Mode 2 section will document the "spec is wrong →
  FAIL, not NEEDS REVISION" rule explicitly, with the four-step
  procedure above. The Mode 2 output structure already includes a
  FAIL state; no new state is added.
- Mode 2 compliance reports may occasionally produce FAIL verdicts on
  spec-level issues. This is intended: a FAIL on the spec is cheaper
  than a silent rewrite discovered downstream.
- The user takes slightly more interruption during a workflow run
  when spec inconsistencies surface mid-implementation. This is
  acceptable; the user's approval is the gate, not the architect's
  judgment.
- ADR 023 remains the rule for factual claims about external state;
  ADR 024 is the parallel rule for workflow decisions touching the
  user-approved spec. Neither supersedes the other.
- Behavioral Rule 3 in CLAUDE.md ("Respect task scope") indirectly
  reinforced this: editing a user-approved spec without permission
  is out of the architect's task scope. ADR 024 makes that
  implication explicit for the Mode 2 surface.

---

## ADR 025: Multi-round Mode 2 Compliance Checks Preserve Prior Rounds

**Date**: 2026-05-12
**Status**: Accepted

### Context

Run-4 also surfaced a file-management gap in multi-round Mode 2
compliance checks. The architect writes its Mode 2 output to
`.cato/state/run-N/compliance-check.md` (per ADR 020 / ADR 021). When
a second Mode 2 round is invoked (typically after the engineer
addresses NEEDS REVISION findings), the architect overwrote the file
in place. Run-4's round-1 compliance-check.md was therefore lost when
round-2 ran; only the round-2 file existed on disk by the time the
reviewer and Mode 3 ran.

This caused a downstream pointer-rot problem: the engineer's round-1
fix wrote an inline comment in `test_is_palindrome.py` citing
`.cato/state/run-4/compliance-check.md §2.spec-bug` as the rationale
for case 29's expected-output change. After round-2 overwrote
compliance-check.md, that section no longer existed — the inline
comment's reference dangled. The reviewer caught the comment's
process-internal framing as a Nit; Mode 3 also discovered the deeper
issue that the cited section had ceased to exist.

The audit-trail loss is also a problem on its own terms: when Mode 3
triages a multi-round run, the rationale for prior NEEDS REVISION
findings, the engineer's responses across rounds, and the architect's
verifications are all part of the run's history. ADR 020's design
intent was that `.cato/state/run-N/` provides a "natural audit trail
… shows the exact handoff content for each step". An overwrite
destroys that trail for multi-round Mode 2 checks.

Run-4 round-3 mitigated this informally by appending the round-3
verdict to compliance-check.md below the round-2 verdict (with a
horizontal-rule separator and a header indicating which round each
section belongs to). That worked for round 3, but it relied on the
architect's choice in the moment, not a documented protocol.

### Decision

Multi-round Mode 2 compliance checks must preserve prior rounds. The
rule is a single canonical path with appended round sections:

A single `.cato/state/run-N/compliance-check.md` accumulates round
sections. Each new round is appended below the prior round with a
separator (`---`) and a header line of the form `# Compliance Check
— run-N (...) — Round K`, where K is the round number (1-indexed).
The latest verdict is always the bottom-most section. The architect
must not overwrite the file in place when a prior round's content
exists; it must read the existing file and append.

The canonical-path-with-append rule applies symmetrically to targeted
Mode 2 re-checks following Mode 3 engineer dispatches. Run-4 round 3
(the Nit-1 fix re-check) is itself a targeted re-check and was
appended below round 2 in exactly this shape; that pattern is now
the documented rule.

Rationale for choosing append-with-headers over a separate-files /
glob scheme:

1. Simpler for main session dispatch. ADR 020 specifies that
   sub-agent prompts reference file paths, and the standard path
   `.cato/state/run-N/compliance-check.md` is stable across rounds.
   A separate-files-plus-glob alternative would require the main
   session to compute "the latest round's file" before each
   dispatch, contradicting ADR 022's mechanical-dispatcher principle.
2. Latest verdict is always bottom-most. Mode 3 and the reviewer
   read the file top-to-bottom and reach the operative verdict last,
   matching how a log file is read.
3. Run-4 round 3 already validated the pattern. Append-with-headers
   worked in practice; no separate scheme needs to be introduced and
   re-validated.
4. Closes the silent-decision surface. Leaving two options open
   (per-round files vs. append) would re-open the kind of unscoped
   judgment call that ADR 023 and ADR 024 are designed to eliminate.
   One rule, applied uniformly.

### Consequences

- architect.md Mode 2 section will document the
  canonical-path-with-append rule, including the round-header format
  and the prohibition on overwriting prior rounds. The protocol
  replaces the implicit "overwrite the file" behavior, which is now
  disallowed for multi-round runs.
- ADR 020's audit-trail intent is honored end-to-end: every round's
  verdict is preserved at the path Mode 3 and the user can read.
- File size grows for runs with many rounds. Acceptable: the
  alternative (history loss) is structurally worse. If a single run
  reaches an unusually high round count, that is itself a signal —
  likely the anti-deadlock rule should fire, escalating to the user,
  rather than the file growing unboundedly.
- Inline references in code (or in other state files) that cite a
  specific round's compliance-check content should cite the round
  explicitly (e.g., `compliance-check.md round 1 §2`). Run-4's
  case-29 comment violated this and was rewritten as part of the
  Nit-1 dispatch.
- ADR 021's "architect Write scoped to .cato/state/run-N/" rule is
  unchanged. The append behavior fits inside that scope.
- ADR 020 is not superseded; ADR 025 specifies how that ADR's "fixed
  path under .cato/state/" rule is honored across multiple rounds.
- The architect needs to Read the existing compliance-check.md before
  Writing the new round, then Write the concatenation. This is one
  extra Read per multi-round dispatch; negligible cost.

---

## ADR 026: Reviewer Is Physically Isolated; Main Session Archives Reviewer Output

**Date**: 2026-05-12
**Status**: Accepted

### Context

Run-5 surfaced an internal inconsistency in `claude-reviewer.md` that
had been latent since the agent was first defined:

- Frontmatter `tools:` lists `Read, Grep, Glob, Bash, WebSearch,
  WebFetch` — no `Write` and no `Edit`.
- "Hard Boundaries" section explicitly states the reviewer does NOT
  have Write or Edit tools.
- "File-Based I/O Protocol" section instructs the reviewer to write
  findings to `reviews/review-YYYYMMDD-NNN.md`.

These three statements cannot all be true. Runs 1–4 papered over the
inconsistency: the reviewer used `cat << EOF > file` via its Bash tool
as an implicit Write workaround, and findings happened to land on disk.
Run-5's reviewer was more literal about its declared tool scope,
refused to use Bash as a backdoor Write, and surfaced the gap honestly
in its final message. The main session then re-dispatched the reviewer
with explicit Bash-heredoc instructions to land the file for run-5.

The Bash-heredoc workaround works, but it is exactly the kind of
"unscoped workaround" that ADR 023 and ADR 024 are designed to
eliminate. It also tells the wrong story about reviewer's role.

The reviewer's design intent is stronger isolation than just "do not
see compliance-check transcripts." The reviewer simulates the
real-world setup where a senior PR reviewer reads code and the spec,
gives written feedback, and never touches the project filesystem
themselves. Anything the reviewer "writes" is text returned to a
person (the architect, via the main session); the archival of that
text into the project's `reviews/` directory is a separate act done
by someone with write access.

### Decision

The reviewer is **physically isolated from the project filesystem with
respect to writes and command execution**. Its tool inventory is
`Read, Grep, Glob, WebSearch, WebFetch` — no `Write`, no `Edit`, no
`Bash`. The reviewer cannot create, modify, or execute anything.

The reviewer's output is its final message, returned verbatim. The
main session takes that verbatim final-message content and writes it
to `reviews/review-YYYYMMDD-NNN.md`. This is the canonical archival
path; architect Mode 3 reads from that archived file.

This archival write is a **sanctioned exception** to ADR 022's
prohibition on the main session writing project files. The exception
is narrow:

- The write target is restricted to `reviews/review-YYYYMMDD-NNN.md`
  (exact directory, exact filename pattern).
- The write content is the reviewer's final-message return, verbatim.
  The main session does not summarize, edit, reformat, or extract
  from it.
- No other path under the project (including `.cato/state/`, source
  files, configuration files, or other paths under `reviews/`) is
  covered by this exception.

The exception is justified because verbatim I/O of an upstream agent's
output to a fixed archival path is not workflow judgment and not
paraphrase, which are what ADR 022 was protecting against. The main
session here is acting as the reviewer's hands, not as a decision
maker.

### Consequences

- `claude-reviewer.md` frontmatter is updated to remove `Bash`; the
  agent now has read-only project access (Read, Grep, Glob) plus
  read-only web access (WebSearch, WebFetch). No execution tool, no
  file-write tool. The implicit Bash-heredoc Write workaround used
  in runs 1–4 is closed off intentionally.
- `claude-reviewer.md` "File-Based I/O Protocol" section is updated
  to specify that output is only the final-message return, with an
  explicit prohibition on attempting workarounds (e.g., asking another
  agent to write the file on the reviewer's behalf).
- `CLAUDE.md` "Reviewer Workflow" section is updated to specify the
  main session's archival responsibility and to cite this ADR as the
  ADR 022 exception.
- Future runs: when the reviewer subagent returns, the main session
  must write the verbatim return to `reviews/review-YYYYMMDD-NNN.md`
  before dispatching architect Mode 3. The next-NNN computation
  follows the existing convention (highest existing NNN for that
  date + 1, or 001 if none).
- Audit trail is preserved end-to-end: reviewer's output is on disk
  in `reviews/`, identical to what the reviewer returned. Architect
  Mode 3 reads the archived file; the file is what gets committed
  per the run-N commit pattern.
- ADR 020 is not superseded. The reviewer still reads files for input
  (spec, source, test output); only its write step changes from
  "reviewer writes the file" to "reviewer returns text, main session
  writes the file."
- ADR 022 is amended in spirit, not in text: the main session may
  write `reviews/review-*.md` as a mechanical archival action on
  reviewer output. The CLAUDE.md edit captures this; this ADR is the
  authoritative source.
- ADR 021's "architect Write scoped to .cato/state/run-N/" is
  untouched. The reviewer archival exception is the main session's,
  not the architect's.
- Existing review files (runs 1–5) remain in `reviews/`; the change
  applies to runs 6 onward.

### Notes

The Bash-heredoc workaround discovered in run-5 retrospect was the
kind of failure mode that survived four runs because it produced the
right artifact for the wrong reason. The lesson: agent definitions
that are internally inconsistent will silently route around the
inconsistency via whatever tool happens to be available, and the
visible output looks correct. The fix is to remove the route, not to
formalize it.
