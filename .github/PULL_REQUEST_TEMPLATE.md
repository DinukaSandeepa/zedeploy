## What this changes

<!-- Stack: nextjs / <new stack> / repo-wide -->

## Checklist

- [ ] One stack per PR
- [ ] `README.md`, `SKILL.md` and `CONTRIBUTING.md` in the stack folder are updated
- [ ] `bash -n` (and `shellcheck` if available) pass on every changed script
- [ ] `skill.sh` tested twice against local files; second run changed nothing
- [ ] Tested on a fresh server for each OS version listed: one good deploy, one rollback
- [ ] Deploy script, sudo helpers and root-parsed config stay root-owned
- [ ] No new sudo rights without a validating helper
- [ ] No secrets committed
- [ ] New stack: row added to the root `README.md` table

## Tested on

<!-- e.g. Ubuntu 24.04 on a 1 vCPU / 1 GB VPS -->
