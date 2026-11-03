#!/usr/bin/env bash
# Run inside your Next.js project root:
#   curl -fsSL https://raw.githubusercontent.com/DinukaSandeepa/zedeploy/main/skill.sh | bash
# Adds the deploy workflow, health check route and Claude skill. Never overwrites existing files.
set -euo pipefail
BASE=${BASE:-https://raw.githubusercontent.com/DinukaSandeepa/zedeploy/main}

grep -qs '"next"' package.json || { echo "Run this inside a Next.js project (no package.json with next found)." >&2; exit 1; }

get() { # <path in zedeploy repo> <destination>
  if [ -e "$2" ]; then echo "skip (exists):  $2"; return; fi
  mkdir -p "$(dirname "$2")"
  curl -fsSL "$BASE/$1" -o "$2" && echo "created:        $2"
}

get .claude/skills/nextjs-zero-downtime-deploy/SKILL.md .claude/skills/nextjs-zero-downtime-deploy/SKILL.md
get deploy.yml .github/workflows/deploy.yml

dir=app; [ -d src/app ] && dir=src/app
route="$dir/api/health/route.ts"
if [ -e "$route" ]; then
  echo "skip (exists):  $route"
else
  mkdir -p "$(dirname "$route")"
  printf 'export const dynamic = "force-dynamic";\n\nexport async function GET() {\n  return Response.json({ ok: true });\n}\n' > "$route"
  echo "created:        $route"
fi

cfg=$(ls next.config.* 2>/dev/null | head -1 || true)
if [ -z "$cfg" ]; then
  printf 'import type { NextConfig } from "next";\n\nconst nextConfig: NextConfig = {\n  output: "standalone",\n  deploymentId: process.env.NEXT_DEPLOYMENT_ID,\n};\n\nexport default nextConfig;\n' > next.config.ts
  echo "created:        next.config.ts"
elif ! grep -q standalone "$cfg"; then
  printf '\nACTION NEEDED: add these two lines inside the config object in %s:\n  output: "standalone",\n  deploymentId: process.env.NEXT_DEPLOYMENT_ID,\n' "$cfg"
fi
echo "done."
