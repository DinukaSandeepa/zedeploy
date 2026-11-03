# <Stack name> stack: deploy to your own server (beginner guide)

<!-- Copy this folder to stacks/<your-stack>/ and replace every <placeholder>.
     Write for a beginner: one action per step, every command copy-pasteable.
     See stacks/nextjs/README.md for a complete example. -->

<One or two sentences: what gets deployed, how, and what happens on each push.>

## How it works (the short version)

```
<push -> build -> ship -> restart/health check -> live>
```

## What you need before you start

- A VPS running **<OS and versions you tested>**, with root or `sudo` access over SSH.
- A domain name pointing at the server's IP address.
- <Your app requirements, e.g. language version, package manager.>

## Step 1. Prepare the server

```bash
<install runtime, web server, git>
```

## Step 2. Run the setup script

```bash
git clone https://github.com/DinukaSandeepa/zedeploy.git
cd zedeploy/stacks/<your-stack>
sudo ./setup-server.sh
```

<Explain each question the script asks.>

## Step 3. Add your app's secrets

<Where the env file lives and how to edit it.>

## Step 4. Create a deploy key for GitHub

<Restricted key: restrict,command="<root-owned deploy script>".>

## Step 5. Add secrets to GitHub

| Name | Value |
|---|---|
| `DEPLOY_SSH_KEY` | ... |

## Step 6. Change your app

### Quick way (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/DinukaSandeepa/zedeploy/main/stacks/<your-stack>/skill.sh | bash
```

### Manual way

<Each file to add or change, with full contents.>

## Step 7. Deploy

<Push, watch Actions, what a first deploy looks like.>

## Something went wrong?

| Problem | What to do |
|---|---|
| ... | ... |

## Roll back by hand

```bash
<commands>
```

## What each file does

| File | Installed on the server at | Purpose |
|---|---|---|
| ... | ... | ... |

## Limits to know about

- <Be honest: downtime, caches, one app per server, etc.>
