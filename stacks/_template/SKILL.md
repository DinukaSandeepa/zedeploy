---
name: <your-stack>-zero-downtime-deploy
description: Set up, deploy, debug, or roll back a <Stack name> app on a single VPS using <process manager>, <web server>, and GitHub Actions. Use when working on this stack's deploy script, workflow, service or web server config, or when asked to deploy, roll back, or provision the server.
---

<!-- Claude loads this file. Keep it short and factual: paths, commands, rules.
     `name` must be lowercase with hyphens and match the folder the user's
     skill.sh installs it into (.claude/skills/<name>/SKILL.md). -->

# Zero-downtime <Stack name> deploy

<One sentence on the architecture.>

## Repo files and server destinations

| Repo file | Server path |
|---|---|
| ... | ... |

## Provision a fresh server

```bash
sudo ./setup-server.sh
```

## App requirements

- <Health check route, build output, config changes.>

## Deploy flow

1. ...

## Manual rollback

```bash
<commands>
```

## Debugging

- Logs: `<command>`

## Rules when editing these files

- Keep the deploy script and anything the web server parses as root **root-owned**.
- Never give the deploy user blanket sudo. Use small root-owned helpers that validate their arguments.
- The SSH key must stay `restrict,command=...`.
