---
name: teamcity
description: Interact with TeamCity CI/CD via the teamcity CLI. Use when the user asks about builds, build configurations (jobs), pipelines, agents, queues, or anything related to TeamCity. Triggers on mentions of builds, CI, pipelines, run status, build agents, or teamcity.
allowed-tools: Bash(teamcity *)
---

# TeamCity CLI

The `teamcity` CLI manages TeamCity builds, jobs, pipelines, projects, and agents.

## Read-Only Mode

When `TEAMCITY_RO=1` is set in the environment (e.g., in coding sessions), the CLI
refuses write operations. Check with `teamcity config list` — it shows environment
overrides at the bottom.

To perform write operations when `TEAMCITY_RO=1` is set, override it inline:

```bash
TEAMCITY_RO=0 teamcity run start <job-id> --branch @this
```

This will prompt the user for approval before executing. Always use `TEAMCITY_RO=0`
prefix for write commands when the environment has `TEAMCITY_RO=1`.

## Repo Linking

Repos can be linked to a TeamCity project/job via `teamcity.toml` at the repo root.
This enables commands like `teamcity run start` (no args) and `--branch @this`.

```bash
teamcity link --auto            # auto-discover from git remotes
teamcity link --project X --job Y
cat teamcity.toml               # inspect binding
```

## Core Commands

### Runs (Builds)

```bash
# List runs
teamcity run list
teamcity run list --job <job-id> --status failure --limit 10
teamcity run list --branch @this              # current git branch
teamcity run list --revision @head            # current HEAD commit
teamcity run list --user @me --since 24h
teamcity run list --json=id,status,webUrl     # structured output

# View a run
teamcity run view <run-id>
teamcity run view <run-id> --json

# Start a run (WRITE — prompts unless TEAMCITY_RO=1 blocks it)
teamcity run start <job-id>
teamcity run start <job-id> --branch @this
teamcity run start <job-id> --revision @head --branch @this
teamcity run start <job-id> --watch --timeout 30m
teamcity run start <job-id> --local-changes   # personal build with uncommitted changes
teamcity run start <job-id> --dry-run         # preview without triggering

# Watch a running build
teamcity run watch <run-id>

# Logs and artifacts
teamcity run log <run-id>
teamcity run artifacts <run-id>
teamcity run download <run-id>

# Analysis
teamcity run tests <run-id>
teamcity run changes <run-id>
teamcity run diff <run-id-1> <run-id-2>
teamcity run tree <run-id>                    # snapshot dependency tree

# Lifecycle (WRITE)
teamcity run cancel <run-id>
teamcity run restart <run-id>
```

### Jobs (Build Configurations)

```bash
teamcity job list
teamcity job list --project <project-id>
teamcity job view <job-id>
teamcity job tree <job-id>                    # dependency tree
teamcity job param list <job-id>              # list parameters

# WRITE
teamcity job pause <job-id>
teamcity job resume <job-id>
```

### Projects

```bash
teamcity project list
teamcity project view <project-id>
teamcity project tree                         # full hierarchy
teamcity project param list <project-id>
```

### Pipelines (YAML Workflows)

```bash
teamcity pipeline list
teamcity pipeline view <pipeline-id>
teamcity pipeline pull <pipeline-id>          # download YAML
teamcity pipeline validate <file>             # validate against server schema
teamcity pipeline schema                      # print JSON schema

# WRITE
teamcity pipeline push <file>
teamcity pipeline create <file>
teamcity pipeline delete <pipeline-id>
```

### Build Queue

```bash
teamcity queue list

# WRITE
teamcity queue approve <run-id>
teamcity queue remove <run-id>
teamcity queue top <run-id>
```

### Agents

```bash
teamcity agent list
teamcity agent view <agent-id>
teamcity agent jobs <agent-id>

# WRITE
teamcity agent disable <agent-id>
teamcity agent enable <agent-id>
teamcity agent authorize <agent-id>
teamcity agent reboot <agent-id>
```

### Raw API Access

```bash
teamcity api '/app/rest/server'
teamcity api '/app/rest/builds' --paginate --slurp
teamcity api '/app/rest/buildQueue' -X POST -f 'buildType=id:MyBuild'  # WRITE
```

## Useful Patterns

```bash
# Check what's running on the current branch
teamcity run list --branch @this --status running

# Find the last successful build for current commit
teamcity run list --revision @head --status success --limit 1

# Watch the latest build
teamcity run list --limit 1 --json=id | jq -r '.[0].id' | xargs teamcity run watch

# Check if linked job is healthy
teamcity run list --limit 5 --json=status | jq -r '.[].status'
```

## Flags Available on Most Commands

| Flag | Description |
|------|-------------|
| `--json` | JSON output (optionally specify fields: `--json=id,status`) |
| `--plain` | Plain text for scripting |
| `--no-header` | Omit table header |
| `-w, --web` | Open in browser |
| `-q, --quiet` | Suppress non-essential output |
| `-V, --verbose` | Detailed/debug output |
| `--no-input` | Disable interactive prompts |
