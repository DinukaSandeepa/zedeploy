# Contributing to zedeploy

Thanks for helping. You can improve an existing stack or add a new one (Django, Laravel, Rails, Go, NestJS, SvelteKit, Nuxt, Bun, ...).

Each stack has its own `CONTRIBUTING.md` with stack-specific rules. Read it before changing that stack.

## Add a new stack

1. **Fork** the repo and create a branch: `git checkout -b stack/<name>`.
2. **Copy the template:**
   ```bash
   cp -R stacks/_template stacks/<name>
   ```
   Use a short lowercase name, e.g. `django`, `laravel`, `sveltekit`.
3. **Fill in every file.** Replace all `<placeholders>`:

   | File | Required | What it is |
   |---|---|---|
   | `README.md` | yes | Beginner guide, same step order as the Next.js one |
   | `SKILL.md` | yes | Claude skill. `name:` must be `<name>-zero-downtime-deploy` |
   | `CONTRIBUTING.md` | yes | Your stack's files, rules and how to test |
   | `setup-server.sh` | yes | One command line after the shebang; safe to re-run |
   | `skill.sh` | recommended | One-line app setup, fetched from `stacks/<name>/` on `main` |
   | deploy script, service, web server config, sudoers, workflow | as needed | Whatever your stack runs |

4. **Add a row** to the "Pick your stack" table in the root `README.md`, with the OS versions you actually tested and yourself as maintainer.
5. **Open a pull request** and fill in the checklist.

## Rules every stack must follow

These keep a beginner's server safe. A PR that breaks one will not be merged.

- **Restricted CI key.** The GitHub Actions key may only run one deploy script, through `restrict,command="<path>"` in `authorized_keys`.
- **Root-owned deploy path.** The deploy script, any sudo helper, and any file the web server or init system reads as root must be owned by root. The app user must not be able to write them.
- **No blanket sudo.** List exact commands in sudoers. If a command needs an argument, write a small root-owned helper that validates it (see `stacks/nextjs/nextjs-drain`).
- **No secrets in git.** Runtime secrets go in a server-side env file, mode `600`.
- **Health check and rollback.** A deploy must check the new version is healthy and go back to the previous release if it is not.
- **Never overwrite user files.** `skill.sh` prints `skip (exists)` instead.
- **Pin versions** in docs and workflows (runtimes, actions). No `curl | sudo bash` from hosts other than the official vendor.
- **Be honest about limits** in the README: downtime, caches, one app per server, and so on.

## Before you open a PR

- `bash -n` every shell script. Run `shellcheck` if you have it.
- Test `skill.sh` against your local files, twice (the second run must change nothing):
  ```bash
  BASE=file://$PWD/stacks/<name> bash stacks/<name>/skill.sh
  ```
- Test on a fresh VPS or VM for each OS version you list: one good deploy, and one broken deploy that rolls back.
- Keep each PR to one stack.

## Style

- Write guides for a beginner: one action per step, every command copy-pasteable, short sentences.
- Shell: `set -euo pipefail`, quote variables, absolute paths for anything run via sudo.
- Comments explain *why*, not *what*.

## Reporting security issues

Do not open a public issue for a vulnerability. Use GitHub's **Security -> Report a vulnerability** on this repo.
