# zedeploy

Beginner-friendly, near-zero-downtime deploys to your own VPS. Push to GitHub and your app updates on your server, with health checks and automatic rollback. No Docker, no Kubernetes, no paid platform.

Each **stack** (Next.js, and more from contributors) is a self-contained folder with:

- a step-by-step beginner guide (`README.md`)
- a one-line server setup script (`setup-server.sh`)
- a one-line app setup script (`skill.sh`)
- a Claude skill (`SKILL.md`) so Claude Code can deploy, debug and roll back for you
- a contribution guide (`CONTRIBUTING.md`)

## Pick your stack

| Stack | Guide | Web server | Process manager | OS | Maintainer |
|---|---|---|---|---|---|
| Next.js (standalone) | [stacks/nextjs](stacks/nextjs/README.md) | Nginx | systemd | Ubuntu 22.04, 24.04, 26.04 | @DinukaSandeepa |

Your stack is not listed? [Add it](CONTRIBUTING.md).

## Quick start (Next.js)

On the server:

```bash
git clone https://github.com/DinukaSandeepa/zedeploy.git && cd zedeploy/stacks/nextjs && sudo ./setup-server.sh
```

In your Next.js project:

```bash
curl -fsSL https://raw.githubusercontent.com/DinukaSandeepa/zedeploy/main/stacks/nextjs/skill.sh | bash
```

Then follow the [full guide](stacks/nextjs/README.md) for secrets, the deploy key and GitHub settings.

## zedeploy vs Coolify vs Dokploy

[Coolify](https://coolify.io) and [Dokploy](https://dokploy.com) are excellent self-hosted platforms (PaaS): a web dashboard that runs many apps and databases in Docker. zedeploy is not a platform. It is a few readable files that deploy **one app** the plain Linux way. Pick the one that fits.

| | zedeploy | Coolify / Dokploy |
|---|---|---|
| What you install | Nginx, systemd, your runtime | Docker, plus the platform (dashboard, its database, reverse proxy) |
| Extra things running on the server | Nothing | The platform's own services, 24/7 |
| Fits a small VPS | Yes, only your app uses RAM | Needs headroom for the platform too |
| How you use it | Push to GitHub | Web dashboard + Git integration |
| Apps per server | One | Many |
| Databases, cron jobs, backups | Bring your own | Built in |
| Preview deploys, multi-server | No | Yes |
| HTTPS | One `certbot` command | Automatic |
| Zero-downtime updates | Rolling restart of 2 instances, health check, automatic rollback | Supported (health checks, rolling updates; see their docs) |
| Containers | No, runs your build directly | Yes |
| Understand everything it does | Yes, a few hundred lines of shell and config | Large codebase |
| Attack surface | SSH key locked to one script, no web panel | Admin web panel that must be secured and updated |
| Learning value | You learn Nginx, systemd and SSH | The platform hides them |

**Choose zedeploy** if you have one app, a small VPS, and want something you can read end to end, with no dashboard to maintain.

**Choose Coolify or Dokploy** if you run several apps or databases, want a UI, preview deploys or multiple servers, or prefer clicking to editing files.

## Repo layout

```
stacks/
  nextjs/       # one folder per stack
  _template/    # copy this to start a new stack
CONTRIBUTING.md # how to add or improve a stack
```

## Security model (all stacks)

- The CI SSH key can only run one root-owned deploy script (`restrict,command=...`).
- The deploy user has no blanket sudo, only a few validated commands.
- The app cannot modify the deploy script or any config the web server parses as root.
- Secrets live on the server, never in git.

## Contributing

New stacks and fixes are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md).
