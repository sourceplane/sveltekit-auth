# 01-product — the site, built in one landing

**Places** the whole tree: the root manifests (`intent.yaml`, `package.json`,
the pnpm workspace and lockfile, `turbo.json`),
`.github/workflows` (`ci.yml` — the baseline's own `baseline.yml` and
`tag.yml` are ignored), the shared TypeScript/ESLint
config, the wrangler renderer and `tooling/wire/worker-secrets.mjs` (the
step that gives each environment's Worker its secrets), the site's README
and its two context pages, the identity file `.rebrand/values.json`,
`.gitkeep` files for the four discovery roots, and `apps/web` — the
SvelteKit site with Auth.js, its Cloudflare adapter build, its deploy
contract, its tests (vitest, run inside the app), the upstream example's ISC
`LICENSE` and its `.env.example`, every key a local run can take.

**Requires** both connections live — GitHub (the App installation on
`githuborg`) and Cloudflare — probed, waited for up to ten minutes each, so a
consent can be clicked while it waits. The platform sees a pull request only
through the installation on the account that owns the repository, so the
probe runs before anything is created.

## What runs

The run's task set-up — the epic, both milestones, both tasks — runs in the
background from the start (`background: true`), so every hook up to `task`
runs beside it; `task` is the first that waits for it.

| hook | what it does |
|---|---|
| `retouch` | the redeploy marker on `apps/web/component.yaml` (`.baseline/tasks/01-product.TaskContract.yaml`'s `affects`) |
| `git-init`, `git-stage` | the rebrand enumerates with `git ls-files`, so the tree is a staged repo first |
| `rebrand` | renames the baseline's identity to the site's over the whole tree (`tooling/rebrand/rebrand.mjs`) |
| `orun-workspace` | writes the site's workspace into `intent.yaml` (`ws_SET_ME` if there is none — loud, not silent) |
| `work-tree` | removes the baseline's own `work:` block from `intent.yaml` — `specs/` and `tasks/` do not ship |
| `promotion` | defers prod's wait on stage until `03-docs` (both environments deploy side by side) |
| `dev-lanes` | keeps dev's verify lanes off main's convergences until `03-docs` |
| `git-restage`, `rebrand-verify` | refuses the landing if any baseline identity is left |
| `repo` | `orun.repo/ensure@v1` — creates `githuborg/reponame` (private unless `repoPrivate=false`) |
| `link` | `orun cloud link` (best effort) then `orun cloud check` — an unlinked repo stops here |
| `secrets` | `orun.integrations/reconcile@v1`, both keys in one hook, created side by side: `CLOUDFLARE_API_TOKEN` from the `workers-deploy` template (Workers Scripts: the site's deploy, and its Worker's secrets); `CLOUDFLARE_ACCOUNT_ID`, the connection fact. Nothing is asked for AUTH_SECRET: the deploy lane generates it on the Worker |
| `task` | finds the phase's task (opened by the run-level list) and yields its key — waiting, if it must, for the background set-up |
| `land` | one PR bound to the task, its commit checked in the box first (`checks: local`: `orun validate`, then `orun plan` as the PR and as the merge would plan it, under a second); merged without waiting for the PR's CI |
| `converge` (await) | `orun.run/watch@v1` on the merge commit's run, read every 5 s; resumes it up to three times |
| `verify` (await) | `orun.http/probe@v1` on both workers.dev URLs |

## What the convergence does

`orun plan --changed` plans `web` on stage and prod (deploy) and — dev's push
activation being deferred — nothing on dev. Each deploy lane installs the
workspace inside its own job tree, builds with `vite build` (the adapter
writes `.svelte-kit/cloudflare/_worker.js` and the static output where
`wrangler.jsonc`'s `main` and `assets.directory` say; every `AUTH_*` value
is unset for the build, so none can be bundled), then runs
`tooling/wire/worker-secrets.mjs` for `<reponame>-web-<env>`: it lists the
secrets the Worker carries (`wrangler secret list`), generates an
AUTH_SECRET only if it carries none — on the first deploy, when the Worker
does not exist yet — and pushes it, with whichever providers' keys are
stored as the site's secrets, in one `wrangler secret bulk` over stdin (a
first push creates the Worker). Then it checks the build output, deploys
with `wrangler deploy`, and smoke-tests it: the home page must render, and
Auth.js's `/auth/session` must answer `null` — which it does only once the
Worker has its AUTH_SECRET. Stage and prod deploy side by side (this phase
deferred the promotion gate), each with its own secret.

## Verified

The repository exists and is linked to the workspace, the convergence run for
the merge commit is green, and
`https://<reponame>-web-{stage,prod}.<subdomain>.workers.dev` answer.

## Troubleshooting

| symptom | cause → fix |
|---|---|
| parks on `waiting for github for <org>` | the workspace's GitHub connection is to another account. Connect the App installation on `<org>` (console → Integrations → GitHub), then `--resume` |
| parks on the `providers` probe for cloudflare | Cloudflare is not connected to the workspace. Connect it (console → Integrations → Cloudflare, paste the Account API token) |
| `link` fails: `… is not linked to workspace` | the credential cannot write links and the platform has not linked the repo. Allow-list it (console → Settings → Git repos) and re-run the phase |
| `land`: `the landing's own check failed — orun plan for …` | the placed tree does not plan; the next line is orun's error. Nothing was pushed. Fix it and re-run the phase |
| `rebrand-verify` lists leftovers | a file carries an identity form no rule renames. Add a rule to `tooling/rebrand/rebrand.mjs` (and a case to `testing/rebrand.test.sh`) |
| `intent.yaml` says `workspace: ws_SET_ME` | `orunWorkspace` was empty and the build ran outside a workspace. Set it and re-run |
| deploy lane: `secret resolution failed … CLOUDFLARE_API_TOKEN` | the reconcile did not run or minted against a revoked connection. Re-connect and re-run the phase; the reconcile re-mints only what is missing |
| deploy lane: Authentication error (10000) | the connection's token lacks Workers Scripts Write. Re-issue it with the permission groups the console's Connect recipe lists |
| smoke fails right after the FIRST deploy | workers.dev route propagation; the composition retries the first deploy and the smoke with backoff (stack-tectonic ≥ 0.19.0). A convergence resume clears what is left |
| `build-app`: `worker-secrets: could not list the secrets … refusing to mint a replacement` | `wrangler secret list` failed for a reason other than "the Worker does not exist" (a revoked token, an API error). Nothing was pushed, so the Worker keeps the AUTH_SECRET it had and no session is lost. Fix the credential and resume the convergence |
| smoke fails on `/auth/session` (a 500, `MissingSecret` in the Worker's log) | the Worker has no AUTH_SECRET: its secret push did not run. Resume the convergence; `build-app` generates one when the Worker carries none |
| `build-app` fails resolving a dependency, or `wrangler` is not found | the job's install did not run inside its tree. The site's `intent.yaml` pins stack-tectonic 0.19.0, where it does; a bump changes the install's layout — `intent.yaml`'s comment says why it is pinned |
| the watch says green, the probe says 404 | another workflow ran on the push and the watch took its run. Only `ci.yml` may run on a push to main |
| re-run lands nothing | the hooks did not run (`--run-hooks`), or the contract names no component — `node tooling/bootstrap/retouch.mjs --check --affects .baseline/tasks/01-product.TaskContract.yaml` in the site's tree says which |
