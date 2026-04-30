# Upstream merge runbook

How to bump our fork against `twentyhq/twenty` upstream. Run monthly, or whenever a security fix lands upstream.

## Why we do this

Our customisations live in:
- `packages/shermin-crm-app/` (Twenty App package — uses public SDK, low conflict risk)
- `shermin/` (top-level, never touched by upstream)
- `.github/workflows/shermin-ci.yaml` (separate workflow file)
- `.github/CODEOWNERS`
- `SHERMIN.md`

Conflicts almost always come from:
- Upstream renaming or restructuring the Apps SDK contract
- Upstream changing our pinned Twenty version's `package.json` deps in incompatible ways
- Lockfile (`yarn.lock`) churn

## Procedure

### 1. Pick a target version

```bash
cd ~/Dev/twenty-shermin
git fetch upstream --tags
git tag --sort=-version:refname | head -5
```

Choose the latest stable `vX.Y.Z` (avoid prereleases). Read the upstream release notes for that tag — note any breaking changes flagged for the Apps SDK or self-hosting.

### 2. Branch and merge

```bash
TARGET=v2.X.Y          # set to the chosen tag
git checkout main
git pull origin main
git checkout -b chore/upstream-bump-$TARGET
git merge $TARGET --no-edit
```

### 3. Resolve conflicts

Common conflict files and how to handle them:

| File | Action |
|---|---|
| `yarn.lock` | Delete, then `yarn install` to regenerate |
| `package.json` (root) | Take theirs, then re-add any Shermin-specific scripts (we don't expect any) |
| Anything in `shermin/` or `packages/shermin-crm-app/` or `SHERMIN.md` | Should never conflict — if it does, our content wins |
| Anything else | Take upstream (`git checkout --theirs path`) |

### 4. Build, test, smoke

```bash
yarn install --immutable
yarn nx build shermin-crm-app
yarn nx run-many --target=build --projects=twenty-server,twenty-front
```

Spin up a local Twenty against a throwaway Postgres:

```bash
cp .env.example .env
docker compose up -d postgres redis
yarn start
```

Smoke-test the Shermin App: load the workspace, confirm the `Retailer` object loads, confirm the workflow rules still apply.

### 5. Open a PR

```bash
git push origin chore/upstream-bump-$TARGET
gh pr create --title "chore: upstream bump to $TARGET" --body "$(cat <<'EOF'
## Upstream bump

- From: $(git log main --format=%s -n 1 -- packages/twenty-server | head -1)
- To: $TARGET

## Release notes

[Link to upstream release notes]

## Conflicts resolved

- (list)

## Smoke tests

- [ ] yarn install clean
- [ ] shermin-crm-app builds
- [ ] twenty-server boots
- [ ] Retailer object loads in workspace
- [ ] Stage-transition workflow still triggers
- [ ] Salesforce push webhook still fires (staging)

EOF
)"
```

### 6. Deploy to staging, smoke, merge

- Wait for CI green.
- Deploy the PR branch to staging EC2.
- Run the verification checklist from `SHERMIN.md`.
- If green, merge with squash to keep `main` history clean.
- Tag the merge commit: `git tag -a "shermin-on-$TARGET" -m "Shermin fork on Twenty $TARGET"` and push.

### 7. Recheck capability assumptions

Twenty is a fast-moving project. Capabilities our data model relies on may change between minor versions in either direction (added, removed, renamed). On every upgrade, recheck:

- **`FILES` field type on custom objects** — currently used for `retailer.documents`. Verify it's still registered in `packages/twenty-shared/src/types/FieldMetadataType.ts` and not gated behind a feature flag.
- **`AttachmentWorkspaceEntity.custom` relation** — currently the side-panel Files surface for custom objects. Verify this relation still exists in `packages/twenty-server/src/modules/attachment/standard-objects/attachment.workspace-entity.ts`.
- **Workflow trigger types** — when we build the stage-validation workflow, we depend on `recordCreated` / `recordUpdated` triggers existing.
- **Apps SDK contract** — our App package's API surface. Breaking changes here block the Shermin App.

If any of the above changes incompatibly, fix the dependency before merging upstream — don't merge then chase.

### 8. Test the Shermin Docker image build

We build a derivative image (`shermin/infra/docker/Dockerfile.shermin`) that sed-patches the compiled `maxFileSize` constant from `'10MB'` to `'100MB'`. The Dockerfile asserts the substitution actually happened, so if upstream restructures the compiled output, the deploy build will fail loudly.

After a tag bump, in the staging environment:

```bash
AWS_PROFILE=shermin-dev shermin/infra/scripts/deploy-twenty.sh
```

Watch the build output. If you see `grep` failing or `Patched maxFileSize to 100MB` missing:

1. SSH into the EC2: `aws ssm start-session --target $(terraform output -raw ec2_instance_id) --profile shermin-dev`
2. Pull the new upstream image and inspect:
   ```
   docker pull twentycrm/twenty:<new-tag>
   docker run --rm -it twentycrm/twenty:<new-tag> grep -n maxFileSize /app/packages/twenty-server/dist/engine/constants/settings/index.js
   ```
3. Update the sed pattern in `Dockerfile.shermin` to match.
4. Re-run the deploy.

## When the merge is too painful

If a single upstream bump becomes >2 hours of conflict resolution, stop and reassess:
- Was it a major version bump (e.g. v3.0.0)? Read the migration guide before merging.
- Did upstream change the Apps SDK contract? May need to refactor `shermin-crm-app/` first.
- Are we touching `twenty-server/` or `twenty-front/` source somewhere we shouldn't be? If yes, that's the actual problem — fix the discipline, not the merge.

## When NOT to merge

- Upstream pre-releases / RCs (always wait for stable).
- Within 7 days of a Shermin production deploy (let things settle first).
- Major version bumps without reading the migration guide.
