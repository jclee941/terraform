---
name: session-init
description: Auto-initialize Kratos and In-Memoria at session start
globs:
  - '**/*'
alwaysApply: true
---

# Session Initialization Rule

## MANDATORY: Execute IMMEDIATELY at Session Start

At the **VERY FIRST action** of every new conversation, before ANY other work:

### Step 1: Initialize Kratos Project (ALWAYS)

```
kratos_project_switch(project_path="{CWD}")
```

Where `{CWD}` is the current working directory from the `<env>` block.

**MUST execute** - Kratos memories are project-scoped. Without this, memories go to wrong project.

### Step 2: Get Project Blueprint (ALWAYS - Lightweight)

```
in-memoria_get_project_blueprint(path="{CWD}")
```

**MUST execute FIRST** - Returns ~90 tokens (68% more efficient than auto_learn).
- Returns: hasIntelligence, techStack, entryPoints, structure
- If `hasIntelligence: false` → proceed to Step 3
- If `hasIntelligence: true` → skip Step 3, start working

### Step 3: Learn Intelligence (ONLY IF NEEDED)

```
in-memoria_auto_learn_if_needed(path="{CWD}")
```

**Execute ONLY when** `get_project_blueprint` returns `hasIntelligence: false`.
- Code projects: learns patterns, concepts, features (~280 tokens)
- IaC projects: creates project metadata (0 patterns is OK)
- Empty/non-code: safely returns without error

### Step 4: Verify (Optional - only if errors)

```
kratos_project_current()
```

## Execution Requirements

| Requirement | Description |
|-------------|-------------|
| **Timing** | FIRST action, before reading files or answering |
| **Silent** | Do NOT announce ("I'm initializing...") |
| **Parallel** | Run both tools in parallel for speed |
| **No Permission** | Do NOT ask user for permission |
| **Report Errors** | Only speak if initialization fails |

## Example (Correct)

```
User: "What files are in this project?"

Agent thinking: "New session. CWD is /home/jclee/myproject. Must init first."

Agent actions (parallel, silent):
  - kratos_project_switch(project_path="/home/jclee/myproject")
  - in-memoria_get_project_blueprint(path="/home/jclee/myproject")
  
Agent thinking: "Blueprint shows hasIntelligence: false. Need to learn."

Agent action (if needed):
  - in-memoria_auto_learn_if_needed(path="/home/jclee/myproject")

Agent response: "Here are the files..." (answers user's actual question)
```

## Anti-Patterns (WRONG)

| Wrong | Why |
|-------|-----|
| Skip init for IaC projects | Still needs Kratos for memories |
| Ask "Should I initialize?" | Rule says MANDATORY, no permission needed |
| Say "Initializing Kratos..." | Rule says SILENT execution |
| Init after answering | Must be FIRST action |
| Run sequentially | Run in PARALLEL for speed |
| Always call auto_learn_if_needed | Check blueprint first - 68% token savings |

## Why This Matters

- **Kratos**: Project-scoped memory. Wrong project = lost/misplaced memories.
- **In-Memoria**: Codebase intelligence. Even 0 patterns creates valid project metadata.
- **Consistency**: Every session starts with correct project context.
