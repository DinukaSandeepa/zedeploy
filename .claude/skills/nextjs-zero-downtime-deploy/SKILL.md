---
name: nextjs-zero-downtime-deploy
description: Set up, deploy, debug, or roll back a Next.js (standalone output) app on a single VPS using systemd, Nginx, and GitHub Actions with rolling restarts. Use when working on deploy.sh, deploy.yml, the nextjs@ systemd unit, Nginx upstream config, or when asked to deploy, roll back, or provision the server.
---

# Zero-downtime Next.js deploy (systemd + Nginx + GitHub Actions)

Two Next.js instances (ports 3000, 3001) run behind Nginx. Each deploy restarts them one at a time while the other serves traffic.

## Repo files and server destinations

| Repo file | Server path |
|---|---|
| `nextjs_.service` | `/etc/systemd/system/nextjs@.service` (note the rename) |
| `nginx-myapp.conf` | `/etc/nginx/conf.d/myapp.conf` |
| `nextjs-upstream.conf` | `/etc/nginx/nextjs-upstream.conf` (owned by `deploy`) |
| `sudoers-deploy` | `/etc/sudoers.d/deploy` |
| `deploy.sh` | `/var/www/myapp/bin/deploy.sh` |
| `deploy.yml` | `.github/workflows/deploy.yml` in the app repo |

Server layout: `/var/www/myapp/{bin,releases/<ts>,current -> releases/<ts>,shared/.env.production,shared/static}`.

## Provision a fresh server

Run as root from a checkout of this repo. It prompts for app name and domain (defaults `myapp`, `example.com`); paths below use the default name:

```bash
sudo ./setup-server.sh
```

Then:
1. Add runtime secrets (`MONGODB_URI`, `BETTER_AUTH_SECRET`, ...) to `/var/www/myapp/shared/.env.production`. The script already generates `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY`.
2. Edit `server_name` in `/etc/nginx/conf.d/myapp.conf`, then `sudo certbot --nginx -d <domain>`.
3. Create the restricted CI key: `ssh-keygen -t ed25519 -f gh_deploy -C gh-actions -N ""`. Add the public key to `/home/deploy/.ssh/authorized_keys` prefixed with `restrict,command="/var/www/myapp/bin/deploy.sh"`.
4. GitHub secrets: `DEPLOY_SSH_KEY`, `DEPLOY_KNOWN_HOSTS`, `DEPLOY_USER`, `DEPLOY_HOST`. Variable: `APP_URL`.

## App requirements (Next.js side)

- `next.config.ts`: `output: "standalone"` and `deploymentId: process.env.NEXT_DEPLOYMENT_ID`.
- `app/api/health/route.ts` returning `Response.json({ ok: true })` with `dynamic = "force-dynamic"`. `deploy.sh` gates on it.
- Build on the same OS/arch as the VPS (Ubuntu runner, Ubuntu VPS) because of native modules like `sharp`.
- Workflow uses `npm`; swap install/cache lines for pnpm or bun.

## Deploy flow

Push to `main` -> Actions builds, assembles `.next/standalone` + `public` + `.next/static`, tars it, streams it over SSH to `deploy.sh`. The script:
1. Unpacks to `releases/<timestamp>` and aborts if `server.js` is missing.
2. Merges `.next/static` into `shared/static` (Nginx serves it, so old chunks survive).
3. Flips `current` atomically.
4. Per port: mark `down` in Nginx upstream -> wait 2s -> `systemctl restart nextjs@<port>` -> poll `/api/health` up to 60s -> mark `up`.
5. On a failed health check: restore the previous symlink, restart touched ports, exit 1.
6. Keeps the last 5 releases.

## Manual rollback

```bash
ls /var/www/myapp/releases
ln -sfn /var/www/myapp/releases/<ts> /var/www/myapp/current_tmp
mv -Tf /var/www/myapp/current_tmp /var/www/myapp/current
sudo systemctl restart nextjs@3000 && sleep 10 && sudo systemctl restart nextjs@3001
```

## Debugging

- Instance logs: `journalctl -u nextjs@3000 -n 100 --no-pager`
- Nginx config: `sudo nginx -t`; upstream state: `cat /etc/nginx/nextjs-upstream.conf` (a stuck `down` means a failed deploy).
- Deploy lock: `/var/www/myapp/.deploy.lock` (`flock`; "another deploy is already running" means a concurrent run).

## Rules when editing these files

- Never widen `sudoers-deploy`; `deploy` may only restart `nextjs@3000/3001`, reload Nginx, and run `nginx -t`. Validate with `sudo visudo -cf`.
- Adding a port requires changes in `PORTS` (`deploy.sh`), `sudoers-deploy`, and `systemctl enable`.
- Do not add `non_idempotent` to `proxy_next_upstream`; POSTs must not be retried.
- The forced-command SSH key must stay `restrict,command=...`.
- `deploy.sh` runs as `deploy`, so only `sudo` commands listed in sudoers will work.

## Known limits

Near-zero, not guaranteed zero, downtime (long requests can be cut at restart). ISR/`revalidateTag` caches are per-instance. A crashed instance restarts from the current symlink, so both can briefly differ mid-rollout.
