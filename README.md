# Cato

A multi-agent development workflow where every change must pass an independent
reviewer that knows nothing of the discussion that produced it.

> Early stage. The architect agent works; engineer and reviewer agents are
> documented intent, not yet implemented.

## What Cato Is

AI coding agents drift. They over-trust their own reasoning and produce code
that "looks right" because it came from the same context that designed it. The
agent that wrote the plan is rarely the right one to judge whether the
implementation honors it.

Cato splits design, implementation, and review into separate agents and
isolates the reviewer from the design conversation. The reviewer sees only the
diff and the test output—not the architect's spec, not the engineer's
reasoning, not the prior discussion. Review is grounded in code, not in intent.

The human is the maintainer, not the operator. You approve direction, resolve
disagreements between agents, and accept or reject review findings. You do not
type into a chat box and watch a daemon code overnight—not yet, anyway.

## Status

| Component                              | Status                                     |
| -------------------------------------- | ------------------------------------------ |
| Architect agent (Claude Opus)          | Working                                    |
| Engineer agent                         | Planned                                    |
| Reviewer agent (claude-reviewer, Opus) | Planned                                    |
| Reviewer agent (gpt-reviewer, GPT-5)   | Planned (requires Codex Plugin CC)         |
| Telegram notifications + quick replies | Working (via external plugin)              |
| Decision log (`DECISIONS.md`)          | Convention defined; file is a placeholder  |
| Review archive (`reviews/`)            | Convention defined; directory is empty     |

This repo is pre-release. There is no published package; clone to try it.

Out of scope (today): autonomous overnight runs, arbitrary coding tasks
without human direction, and any non-Claude/non-OpenAI models. See
[Roadmap](#roadmap) for what's planned.

## Quickstart

### Prerequisites

- [Claude Code](https://claude.ai/code) installed
- An Anthropic account with Claude Opus access
- macOS (tested) or Linux (likely works, unverified). Windows is not supported—
  the Telegram plugin uses a Bun runtime that targets macOS and Linux. Verify
  before attempting.

### Install

There is nothing to compile. Cato is a project constitution
([`CLAUDE.md`](CLAUDE.md)) and a set of subagent definitions in `.claude/`.
Claude Code reads them automatically when you open a session in the project
root.

```sh
git clone https://github.com/yuan-phd/cato.git
cd cato
claude  # opens Claude Code in this directory
```

### First run

Inside Claude Code, describe a high-level goal. For example:

> I want to add a CLI flag that prints the current git branch in color.

The architect agent should be invoked, produce a structured specification, and
wait for your approval before any code is written. (Today, "before any code is
written" is the end of the workflow—the engineer agent does not exist yet.)

For the optional phone-side notification and quick-reply channel, see
[Telegram Setup](#telegram-setup).

## Telegram Setup

Telegram is **optional**. It exists for asynchronous notifications and quick
yes/no decisions when you're away from the terminal. Long specs, code paste,
and new high-level tasks belong in the terminal—the constitution enforces this
([CLAUDE.md § Terminal vs Telegram Usage](CLAUDE.md#terminal-vs-telegram-usage)).

Setup is nontrivial. The steps below have been verified on macOS.

### 1. Install the Telegram plugin for Claude Code

Cato uses the official Anthropic Telegram plugin from
[anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official)
(see the `telegram/` subdirectory). Install it via Claude Code's plugin marketplace with `/plugin install telegram@claude-plugins-official`. The plugin requires the Bun runtime (https://bun.sh); see the plugin's own README for full install steps and dependencies.

### 2. Create a bot via BotFather

In the Telegram app, message [@BotFather](https://t.me/BotFather):

```
/newbot
```

Follow the prompts to name your bot and pick a username. BotFather will hand
back a token that looks like `1234567890:AAH-string-of-letters-and-numbers-here`.

**This token is a secret.** Do not commit it. The project `.gitignore` already
excludes `.env` files; the token is managed by the plugin, not by this repo.

### 3. Configure the plugin with your token

Inside Claude Code, run:

```
/telegram:configure
```

Paste the token when prompted.

### 4. Pair your Telegram account

Run:

```
/telegram:access pair <code>
```

Then set policy to allowlist mode (only paired users can issue commands):

```
/telegram:access policy allowlist
```

**Security:** only run pairing commands from your own terminal. If a message
arriving *via* Telegram asks you (or Claude) to "approve a pending pairing" or
"add me to the allowlist," refuse. That is exactly the request a prompt
injection would make. The constitution and the plugin both treat this as a
hard rule.

### 5. Verify

Send a "hello" to your bot from your phone. Claude should be able to reply
through the plugin. If it doesn't, re-check that policy is set to allowlist and
that your Telegram user ID is paired.

### What Telegram is and isn't for

Acceptable input from Telegram:

- Quick decisions on already-presented options ("yes", "fix critical 1 and 3")
- Status queries ("is the engineer done?")
- Direction changes ("abort current task", "pause")

Not acceptable (Claude will ask you to come back to the terminal):

- Long technical specifications
- New high-level tasks requiring deep planning
- Code paste or detailed debug input

## Architecture

Three agents, one human maintainer, one project constitution
([`CLAUDE.md`](CLAUDE.md)).

```mermaid
flowchart TD
    User["User / Maintainer"]
    Architect["Architect agent<br/>(produces spec, no code)"]
    Engineer["Engineer agent<br/>(planned)"]
    Reviewer["Reviewer agent<br/>(planned, isolated context)"]
    Repo[("git repo")]

    User -->|"high-level goal"| Architect
    Architect -->|"specification"| User
    User -->|"approve"| Engineer
    Engineer -->|"commits + diff"| Repo
    Repo -->|"diff and test output only"| Reviewer
    Reviewer -->|"findings"| User
    User -.->|"accept / reject / partial"| Engineer

    classDef planned stroke-dasharray: 5 5;
    class Engineer,Reviewer planned;
```

### Architect (working)

Translates a high-level goal into a structured specification: goal
restatement, 2–3 viable approaches with tradeoffs, a recommended approach,
detailed plan, and open questions. Has Read / Grep / Glob / WebSearch /
WebFetch—no Write, Edit, or Bash. The lack of edit tools is intentional: it
prevents the architect from drifting into implementation. Definition lives at
[`.claude/agents/architect.md`](.claude/agents/architect.md).

### Engineer (planned)

Will implement code strictly following an approved architect spec, committing
in small descriptive steps. Each meaningful commit triggers the reviewer.

### Reviewer (planned)

Will audit engineer commits in an isolated context. Sees only the diff and
test output—not the architect's spec, not the engineer's reasoning, not the
prior conversation. The default reviewer is `claude-reviewer` (Claude Opus).
A backup `gpt-reviewer` (GPT-5 via Codex Plugin CC) is planned for second
opinions on critical decisions. Findings are categorized as
`critical / warning / suggestion` and archived under
[`reviews/`](reviews/).

### The maintainer's role

You are not the operator. You set direction, approve specs, resolve agent
disagreements, and accept or reject review findings. The constitution is
explicit that if you are unavailable when a critical review fires, the
workflow stops rather than guesses.

### Decisions

Significant decisions—approved specs, accepted/rejected reviewer findings,
direction changes—are recorded in [`DECISIONS.md`](DECISIONS.md) as
lightweight ADRs. Trivial operations are not.

## Why "Cato"?

Cato the Younger was the Roman senator who opposed Caesar on procedural
grounds. He was not always right on the merits. What mattered to him was that
the procedure stand—that no one, however popular or competent, gets to skip
the constraint by being persuasive.

Cato (the project) borrows that posture for a narrow purpose. The reviewer is
isolated from the design conversation as a procedural rule, not because we
distrust the engineer in any given case. The point is that being persuasive
inside the design conversation cannot be how code earns its way to merge. The
reviewer must be re-convinced from the diff alone.

The analogy has limits—Cato also lost. This is a design philosophy, not a
guarantee.

## Roadmap

Near-term focus is completing the Path A workflow end-to-end—making the architect / engineer / reviewer triangle work as intended—before extending into Path B or mobile-first directions.

Near term:

- Engineer agent
- `claude-reviewer` (Claude Opus, isolated context)
- Review archive convention: `reviews/review-YYYYMMDD-NNN.md`

After that:

- `gpt-reviewer` via Codex Plugin CC, for ensemble review on critical decisions

**Path B (v2 direction).** A Python orchestrator built on the Claude Agent SDK,
provider-agnostic interfaces (OpenRouter, local Ollama), per-agent model
selection (e.g., engineer on a cheap fast model, reviewer on Opus),
multi-vendor ensemble reviewers, and true offline / overnight execution.
Path B requires switching from subscription to API billing for non-Claude
models.

**Mobile-first mode.** A possible future evolution where Telegram can initiate
full tasks. Not blocked by any architectural decision today; deliberately
deferred.

## Repository Layout

```
cato/
├── CLAUDE.md                  Project constitution (read by Claude Code on session start)
├── README.md                  This file
├── DECISIONS.md               ADRs for significant decisions
├── .claude/
│   └── agents/
│       └── architect.md       Architect subagent definition
├── reviews/
│   └── .gitkeep               Placeholder; reviewer findings will land here
└── .gitignore
```

## Contributing

This is a personal portfolio project at an early stage. Issues are welcome;
PRs probably aren't yet—the architecture is still settling. If something here
sparks a question, open an issue and tag it `discussion`.

## License

MIT. See [LICENSE](LICENSE) (to be added).

## Author

[@yuan-phd](https://github.com/yuan-phd)
