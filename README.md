# Zero-downtime Next.js on a single VPS (systemd + Nginx + GitHub Actions)

## Files and where they go

| File | Destination on the server |
|---|---|
| `nextjs@.service` | `/etc/systemd/system/nextjs@.service` |
| `nginx-myapp.conf` | `/etc/nginx/conf.d/myapp.conf` |
| `nextjs-upstream.conf` | `/etc/nginx/nextjs-upstream.conf` (owned by `deploy`) |
| `sudoers-deploy` | `/etc/sudoers.d/deploy` |
| `deploy.sh` | `/var/www/myapp/bin/deploy.sh` |
| `deploy.yml` | `.github/workflows/deploy.yml` in your repo |

## Server layout

```
/var/www/myapp/
  bin/deploy.sh
  releases/<timestamp>/     # each standalone build (last 5 kept)
  current -> releases/<ts>  # atomic symlink
  shared/.env.production    # runtime env, never in git
  shared/static/            # merged hashed assets from all recent releases (Nginx serves these)
```

## One-time server setup

```bash
# user + dirs
sudo adduser --disabled-password --gecos "" deploy
sudo mkdir -p /var/www/myapp/{bin,releases,shared/static}
sudo chown -R deploy:deploy /var/www/myapp

# files
sudo install -m 755 -o deploy -g deploy deploy.sh /var/www/myapp/bin/deploy.sh
sudo install -m 644 nextjs@.service /etc/systemd/system/nextjs@.service
sudo install -m 644 -o deploy -g deploy nextjs-upstream.conf /etc/nginx/nextjs-upstream.conf
sudo install -m 644 nginx-myapp.conf /etc/nginx/conf.d/myapp.conf
sudo install -m 440 sudoers-deploy /etc/sudoers.d/deploy
sudo visudo -cf /etc/sudoers.d/deploy

# runtime env (include a fixed Server Actions key, same for both instances)
sudo -u deploy nano /var/www/myapp/shared/.env.production
#   MONGODB_URI=...
#   BETTER_AUTH_SECRET=...
#   NEXT_SERVER_ACTIONS_ENCRYPTION_KEY=<openssl rand -base64 32>

sudo systemctl daemon-reload
sudo systemctl enable nextjs@3000 nextjs@3001   # start on boot; they start after the first deploy
sudo nginx -t && sudo systemctl reload nginx
```

## SSH key for GitHub Actions (restricted)

```bash
ssh-keygen -t ed25519 -f gh_deploy -C gh-actions -N ""
```

Add to `/home/deploy/.ssh/authorized_keys` (one line). `restrict` disables
forwarding/pty and `command=` means this key can ONLY run the deploy script,
nothing else:

```
restrict,command="/var/www/myapp/bin/deploy.sh" ssh-ed25519 AAAA... gh-actions
```

GitHub repo secrets: `DEPLOY_SSH_KEY` (private key), `DEPLOY_KNOWN_HOSTS`
(output of `ssh-keyscan -t ed25519 your.host`), `DEPLOY_USER` (`deploy`),
`DEPLOY_HOST`. GitHub repo variable: `APP_URL` (e.g. `https://example.com`).

## Changes in the Next.js app

`next.config.ts`:

```ts
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  // Skew protection: ties each client to the build that served it
  deploymentId: process.env.NEXT_DEPLOYMENT_ID,
};

export default nextConfig;
```

`app/api/health/route.ts` (the deploy gates on this; add a cheap DB ping if you want):

```ts
export const dynamic = "force-dynamic";

export async function GET() {
  return Response.json({ ok: true });
}
```

## How a deploy runs

1. Push to `main` -> Actions builds, assembles `.next/standalone` + `public` + `.next/static`, tars it.
2. The tarball is streamed over SSH straight into `deploy.sh` (no scp, no temp files on the server).
3. `deploy.sh` unpacks to a new release dir, merges static assets, flips `current` atomically.
4. For each port (3000, then 3001): mark `down` in Nginx -> wait 2s -> restart -> poll `/api/health` up to 60s -> mark `up`.
5. If an instance never becomes healthy, it stays `down`, the symlink is restored, the touched instances are restarted on the previous release, and the job fails. The other instance has been serving traffic the whole time.

## Manual rollback

```bash
ls /var/www/myapp/releases                      # pick the previous one
ln -sfn /var/www/myapp/releases/<ts> /var/www/myapp/current_tmp
mv -Tf /var/www/myapp/current_tmp /var/www/myapp/current
sudo systemctl restart nextjs@3000 && sleep 10 && sudo systemctl restart nextjs@3001
```

## Known limits (be honest in your docs)

- **Near-zero, not guaranteed zero downtime.** In-flight requests on a restarting instance are drained for a couple of seconds, not tracked; very long requests can still be cut at restart.
- **ISR / `revalidateTag` caches are per-instance.** If you rely on them, add a shared cache handler (e.g. Redis) or accept brief inconsistency between the two instances.
- **Crash restarts pick up the new release.** If an instance crashes while the other is mid-rollout, `Restart=always` starts it from the current symlink. That is fine in practice but means both can briefly differ.
- **Build on the same OS family/arch as the VPS** (Ubuntu runner -> Ubuntu VPS), because standalone output can include native modules (e.g. `sharp`).
- Uses `npm`; swap the install/cache lines in `deploy.yml` if you use pnpm or bun.
