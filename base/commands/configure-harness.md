---
description: Configures and audits the AI host profile (OMP + Antigravity, Claude Code, Cursor, OpenCode), model role mapping (reasoning, code, review, security), and language preference.
---

# /configure-harness

Manages and audits alignment between the active AI host, model role assignments, and language settings:

```bash
./bin/kde-config configure-harness
```

---

## Guided Configuration Flow (Mandatory for AI Agents)

The agent must detect the active harness and use `AskUserQuestion` (or `ask`) to configure preferences:

### Question 1 — Language Preference (`language`) (singleSelect):
- **"English (en) (Recommended)"** — Standard English for all internal configs, runlogs, and contracts.
- **"Português do Brasil (pt-BR)"** — Brazilian Portuguese user-facing responses translated by the AI agent.

### Question 2 — Reasoning & Architecture Role (`reasoning`) (singleSelect):
- **"google-antigravity/gemini-3.7-flash (Recommended)"** — Ultra-fast, fluid reasoning, massive context window.
- **"google-antigravity/gemini-3.7-pro"** — Deep reasoning and complex architectural decomposition.
- **"anthropic/claude-3.7-sonnet"** — Hybrid reasoning with extended thinking.
- **"deepseek/deepseek-r1"** — Pure algorithmic and logical reasoning.

### Question 3 — Implementation & Code Role (`code`) (singleSelect):
- **"google-antigravity/gemini-3.7-flash (Recommended)"** — Precise execution for shell, C/Rust, and kernel patches.
- **"anthropic/claude-3.7-sonnet"** — Precision engineering for complex refactoring.
- **"openai/gpt-4o"** — Standard multi-tasking.

### Question 4 — Review & Sanity Role (`review`) (singleSelect):
- **"google-antigravity/gemini-3.7-flash (Recommended)"** — Fast output contract validation and regression checks.
- **"anthropic/claude-3.5-haiku"** — Lightweight verification.

### Question 5 — Security & Defense Role (`security`) (singleSelect):
- **"anthropic/claude-3.7-sonnet (Recommended)"** — Rigorous defensive audits, permissions, and hardware security analysis.
- **"google-antigravity/gemini-3.7-flash"** — Fast risk surface scanning.

---

### Mapping Answers to Command Execution:

```bash
./bin/kde-config configure-harness --set <harness> <reasoning> <code> <review> <security> [language]
```

To set language preference directly:
```bash
./bin/kde-config configure-harness --set-lang <en|pt-BR>
```

To auto-sync with the active harness:
```bash
./bin/kde-config configure-harness --sync
```

---

## Output Format (Mandatory across all tools)

Always report in these four phases, in this exact order:

### 1. Plan
Command to be executed and what it changes.

### 2. Execution
One line per step (`✅`, `⏭️`, `⚠️`, `❌`).

### 3. Summary
Table with Changed, Language, Unchanged, Backup, and How to Revert.

### 4. Recommended Actions
Mandatory if any `⚠️` or `❌` occurs, providing the exact 1-line command to fix each issue.
