# Deploy a Next.js app to your own server (beginner guide)

This repo lets you deploy a Next.js app to a single Linux server (VPS). Every time you push code to the `main` branch on GitHub, the app is built and updated on your server automatically. Visitors keep using the site while it updates.

## How it works (the short version)

```
You push to GitHub -> GitHub builds your app -> sends it to your server over SSH
-> server restarts app copy #1, checks it works -> restarts app copy #2
```

Your server runs **two copies** of your app (ports 3000 and 3001) behind **Nginx**, a web server that sends visitors to a healthy copy. While one copy restarts, the other keeps serving. If the new version fails its health check, the server goes back to the previous version by itself.

## What you need before you start

- A VPS running **Ubuntu 22.04, 24.04 or 26.04**, with root or `sudo` access over SSH.
- A domain name pointing at the server's IP address (an A record).
- A Next.js app on GitHub that uses **npm**.
- A computer with a terminal and `ssh`.

## Step 1. Prepare the server

Log in to your server and install Nginx, Node.js 22 and git:

```bash
sudo apt update
sudo apt install -y nginx git curl
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
```

## Step 2. Run the setup script

On the server, download this repo and run the script:

```bash
git clone https://github.com/DinukaSandeepa/zedeploy.git
cd zedeploy
sudo ./setup-server.sh
```

The script asks two questions:

| Question | What to answer |
|---|---|
| `App name [myapp]` | A short name using only lowercase letters, numbers, `-` or `_`. Example: `shop`. |
| `Domain [example.com]` | Your real domain. Example: `shop.com`. |

It then creates a `deploy` user, creates the folders under `/var/www/<app name>`, installs the service and Nginx files, and generates a secret key. It prints `server ready` when done.

Below, replace `myapp` with the app name you chose.

## Step 3. Add your app's secrets

Your app's private settings (database address, auth secret and so on) live in one file on the server. They are never stored in git.

```bash
sudo -u deploy nano /var/www/myapp/shared/.env.production
```

The file already has one line, `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY`. Keep it, and add your own below it. Example:

```
MONGODB_URI=mongodb+srv://...
BETTER_AUTH_SECRET=some-long-random-string
```

Save with `Ctrl+O`, `Enter`, then exit with `Ctrl+X`.

## Step 4. Create a deploy key for GitHub

GitHub needs a key to log in to your server. This key is limited: it can run the deploy script and nothing else.

**On your own computer**, create the key pair:

```bash
ssh-keygen -t ed25519 -f gh_deploy -C gh-actions -N ""
```

This makes two files: `gh_deploy` (private, keep secret) and `gh_deploy.pub` (public).

**On the server**, allow the public key. Replace `AAAA...` with the contents of `gh_deploy.pub` (the part after `ssh-ed25519`):

```bash
sudo install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
echo 'restrict,command="/usr/local/bin/nextjs-deploy" ssh-ed25519 AAAA... gh-actions' | sudo tee -a /home/deploy/.ssh/authorized_keys
sudo chown deploy:deploy /home/deploy/.ssh/authorized_keys
sudo chmod 600 /home/deploy/.ssh/authorized_keys
```

The `restrict,command=...` part is what locks the key down. Do not remove it.

## Step 5. Add secrets to GitHub

In your app's GitHub repo go to **Settings -> Secrets and variables -> Actions**.

Under **Secrets**, add:

| Name | Value |
|---|---|
| `DEPLOY_SSH_KEY` | The full contents of the private file `gh_deploy` |
| `DEPLOY_KNOWN_HOSTS` | Output of `ssh-keyscan -t ed25519 your.server.ip` (run on your computer) |
| `DEPLOY_USER` | `deploy` |
| `DEPLOY_HOST` | Your server's IP address or domain |

Under **Variables**, add:

| Name | Value |
|---|---|
| `APP_URL` | `https://your-domain.com` (or `http://` until Step 8) |

## Step 6. Change your Next.js app

### Quick way (one command)

Open a terminal **in your Next.js project folder** and run:

```bash
curl -fsSL https://raw.githubusercontent.com/DinukaSandeepa/zedeploy/main/skill.sh | bash
```

This adds the workflow file, the health check route and the Claude skill. It never overwrites a file you already have, and it prints `skip (exists)` for those. If your `next.config` already exists, it tells you which two lines to add by hand (see item 1 below). Then go to Step 7.

### Manual way

Do these three things in your app's repo instead.

**1. Turn on standalone output** in `next.config.ts`:

```ts
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  // Makes each browser stick to the build it loaded
  deploymentId: process.env.NEXT_DEPLOYMENT_ID,
};

export default nextConfig;
```

**2. Add a health check route** at `app/api/health/route.ts` (use `src/app/...` if your app has a `src` folder). The deploy checks this URL to know the new version works:

```ts
export const dynamic = "force-dynamic";

export async function GET() {
  return Response.json({ ok: true });
}
```

**3. Copy the workflow file.** Copy `deploy.yml` from this repo to `.github/workflows/deploy.yml` in your app's repo. If your build needs `NEXT_PUBLIC_*` variables, add them in the `Build` step.

## Step 7. Deploy

Commit and push to `main`:

```bash
git add .
git commit -m "Add deploy setup"
git push origin main
```

Open the **Actions** tab on GitHub to watch it run. The first deploy takes a few minutes. Until it finishes, your domain shows a `502 Bad Gateway` error because no app is running yet. That is normal.

When the run is green, open your domain. Your app is live. From now on, every push to `main` deploys automatically.

## Step 8. Turn on HTTPS (recommended)

On the server:

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

Follow the prompts. Then set the `APP_URL` variable on GitHub to `https://your-domain.com`.

## Something went wrong?

| Problem | What to do |
|---|---|
| `502 Bad Gateway` after the first deploy | Check the app logs (see below). Usually a missing value in `.env.production`. |
| GitHub run fails at "Deploy over SSH" | Re-check the four secrets from Step 5 and the `authorized_keys` line from Step 4. |
| Deploy says `deploy FAILED and was rolled back` | The new version failed `/api/health`. Check the app logs, fix the code, push again. The old version stayed online. |
| `another deploy is already running` | Wait a minute and re-run the workflow. |
| Domain does not load at all | Check the DNS record points at your server, and that the firewall allows ports 80 and 443. |

Useful commands on the server:

```bash
journalctl -u nextjs@3000 -n 100 --no-pager   # app logs, copy 1
journalctl -u nextjs@3001 -n 100 --no-pager   # app logs, copy 2
sudo nginx -t                                  # check Nginx config
ls /var/www/myapp/releases                     # past versions (last 5 are kept)
```

## Roll back by hand

If a version is live but broken, point the server back at an older one:

```bash
ls /var/www/myapp/releases                      # pick an older folder name
ln -sfn /var/www/myapp/releases/<folder> /var/www/myapp/current_tmp
mv -Tf /var/www/myapp/current_tmp /var/www/myapp/current
sudo systemctl restart nextjs@3000 && sleep 10 && sudo systemctl restart nextjs@3001
```

Then fix the code, or revert the commit on GitHub. The next push will deploy over this.

## What each file does

| File | Installed on the server at | Purpose |
|---|---|---|
| `setup-server.sh` | (run once, not installed) | One-time server setup |
| `skill.sh` | (run once in your app, not installed) | Adds the workflow, health route and skill to your Next.js app |
| `deploy.sh` | `/usr/local/bin/nextjs-deploy` (root-owned) | Unpacks a new version and restarts the app copies one at a time |
| `nextjs_.service` | `/etc/systemd/system/nextjs@.service` | Keeps the app running, restarts it if it crashes |
| `nginx-myapp.conf` | `/etc/nginx/conf.d/myapp.conf` | Sends visitors to the app, serves static files |
| `nextjs-upstream.conf` | `/etc/nginx/nextjs-upstream.conf` (root-owned) | List of app copies; changed only by `nextjs-drain` during a deploy |
| `nextjs-drain` | `/usr/local/sbin/nextjs-drain` (root-owned) | Marks one app copy "down" in Nginx; the only Nginx change `deploy` may make |
| `sudoers-deploy` | `/etc/sudoers.d/deploy` | Lets `deploy` run only the few admin commands it needs |
| `deploy.yml` | `.github/workflows/deploy.yml` in your app repo | GitHub Actions workflow: build, send, deploy, smoke test |

Server folder layout:

```
/var/www/myapp/
  releases/<timestamp>/     # one folder per deploy (last 5 kept)
  current -> releases/<ts>  # link to the live version
  shared/.env.production    # your secrets, never in git
  shared/static/            # JS/CSS files from recent releases, served by Nginx
```

## Limits to know about

- **Nearly zero downtime, not perfectly zero.** Very long requests can be cut when their app copy restarts.
- **One app per server.** The service name, ports and Nginx upstream file are fixed. A second app would overwrite them.
- **Caches are per copy.** If you use ISR or `revalidateTag`, the two copies can briefly differ. A shared cache such as Redis fixes this.
- **Build and server should match.** The workflow builds on Ubuntu, so use an Ubuntu server. Native modules like `sharp` need this.
- **npm only.** For pnpm or bun, change the install and cache lines in `deploy.yml`.
