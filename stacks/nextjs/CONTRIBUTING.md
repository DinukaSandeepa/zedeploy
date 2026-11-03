# Contributing to the Next.js stack

Read the [repo-wide guide](../../CONTRIBUTING.md) first. This file covers what is specific to `stacks/nextjs`.

## What is in this stack

| File | Role |
|---|---|
| `setup-server.sh` | One-line server provisioning, run once as root |
| `skill.sh` | One-line setup inside a Next.js app (workflow, health route, skill, `next.config.ts`) |
| `deploy.sh` | Rolling deploy, installed root-owned as `/usr/local/bin/nextjs-deploy` |
| `nextjs-drain` | Root-owned helper that marks one instance down in Nginx |
| `nextjs_.service` | systemd template, installed as `nextjs@.service` |
| `nginx-myapp.conf`, `nextjs-upstream.conf` | Nginx site and upstream |
| `sudoers-deploy` | The only root commands the `deploy` user may run |
| `deploy.yml` | GitHub Actions workflow copied into the user's app |
| `SKILL.md` | Claude skill, also installed into the user's app by `skill.sh` |

## Rules for this stack

- **Keep root-owned files root-owned.** The app runs as `deploy`. `deploy.sh`, `nextjs-drain` and `/etc/nginx/nextjs-upstream.conf` must never be writable by `deploy`, or the app can gain root.
- **Do not widen `sudoers-deploy`.** If a deploy step needs root, add a small root-owned helper that validates its arguments, like `nextjs-drain`.
- **Ports live in four places.** Changing or adding a port means editing `PORTS` in `deploy.sh` and `nextjs-drain`, `sudoers-deploy`, and the `systemctl enable` in `setup-server.sh`.
- **`setup-server.sh` stays one command line** after the shebang, and must be safe to re-run.
- **`skill.sh` must never overwrite a user's file.** Print `skip (exists)` instead.
- **Do not add `non_idempotent`** to `proxy_next_upstream`. POSTs must not be retried.

## Testing your change

1. `bash -n` every script you touched. Run `shellcheck` if you have it.
2. `skill.sh`: run it in an empty folder with a `package.json` containing `next`, against your local files:
   ```bash
   BASE=file://$PWD/stacks/nextjs bash stacks/nextjs/skill.sh
   ```
   Run it twice. The second run must print only `skip (exists)`.
3. Server changes: test on a fresh VPS or VM for each Ubuntu version you claim (22.04, 24.04, 26.04). Do one deploy that passes, and one with a broken `/api/health` that must roll back.
4. Update `README.md` and `SKILL.md` in this folder if any path, command or behaviour changed.
