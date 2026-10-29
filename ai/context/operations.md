# sveltekit-auth — operating contract (for humans and agents)

This is the standing guide to how this site is deployed and operated.
Instance facts (live URLs, workspace, the secrets it uses) live in
[deployment.md](deployment.md), rendered from probed reality by the
bootstrap's `03-docs` phase; this file is the contract that stays true
between deployments. It is written to give an agent with repository read
access enough context to reason about and operate the site without any
other source.

## What this system is

A SvelteKit site with Auth.js sign-in, on Cloudflare alone, expressed as an
Orun component-native desired-state repo.

- **`apps/web`** — the site: SvelteKit 2 built by `@sveltejs/adapter-cloudflare`
  into one Worker (`.svelte-kit/cloudflare/_worker.js`) plus Static Assets
  (the same directory, for the hashed `_app` chunks and the static files).
  The Worker renders every page, because each reads the visitor's session:
  `/`, `/signin`, `/protected` and `/signout`, Auth.js's own `/auth/*`
  routes (`src/hooks.server.ts` → `src/auth.ts`), and SvelteKit's error
  page for every other path. Sessions are Auth.js's encrypted JWT in an
  httpOnly cookie (`authjs.session-token`, `__Secure-` over HTTPS), sealed
  with the Worker's `AUTH_SECRET`; there is no database. The Auth.js
  configuration is built per request from the Worker's secrets: each
  provider in `src/server/providers.ts` is offered only when every key it
  takes is set, and with none set `/signin` says what to connect. The
  site's tests (vitest) live in `apps/web` and run with `pnpm test` — by
  hand, before a push: `ci.yml`'s lanes do not lint or run them.
- **`tooling/wire/worker-secrets.mjs`** — the deploy lane's secret step (in
  `apps/web/component.yaml`'s `buildCommand`): it gives each environment's
  Worker its AUTH_SECRET (generated once, then kept) and whichever
  providers' keys are stored, with `wrangler secret bulk` over stdin.
  `pnpm --filter @app/web secret:dev` runs it against `apps/web/.env` instead.
- **`tooling/*`** — shared TypeScript and ESLint configuration, and the
  deploy-time wrangler renderer for workers that take wiring.

Environments: **`stage`** and **`prod`** are deployed; **`dev` is
verify-only by design** — lanes build and dry-deploy, nothing deploys.

## Identity and tenancy

Every remote operation runs against ONE Orun workspace, declared in
`intent.yaml` under `execution.state.workspace` — committed, enforced, and
what CI uses. Do not remove it; headless credentials depend on it. If it
reads `ws_SET_ME`, the bootstrap had no workspace to write: set the real one
before anything else.

## How deployment works

1. Merge (or push) to `main`.
2. CI (`.github/workflows/ci.yml`) runs `orun plan --changed` — only
   components whose files changed are planned — then runs each planned lane
   with `orun run --remote-state`, authenticated by GitHub OIDC (the
   exchange resolves this repository's linked workspace server-side).
3. `apps/web` builds once per environment (`vite build`, every `AUTH_*`
   value unset for it; the adapter writes the Worker and the assets where
   `wrangler.jsonc`'s `main` and `assets.directory` say). Then
   `worker-secrets.mjs` lists the secrets `sveltekit-auth-web-<env>`
   carries, generates an AUTH_SECRET only if it carries none (the first
   deploy, which also creates the Worker), and pushes it with the stored
   providers' keys in one `wrangler secret bulk`. If the list fails for any
   reason but "the Worker does not exist", it stops rather than mint a
   replacement. Then `wrangler deploy` ships the Worker and a smoke test
   fetches `/` (it must render) and `/auth/session` (it must answer `null`,
   which Auth.js does only with an AUTH_SECRET).
4. `prod` deploys after `stage` has converged on the same commit
   (`environments.prod.promotion` in intent.yaml).
5. **The convergence run is the deployment.** A green run means every
   planned lane applied. Failed lanes are retried with
   `gh run rerun --failed`, which resumes the same execution.

Caveats that matter:

- A push that touches no component files plans zero lanes — that run is
  green and deployed nothing. Never treat "latest run green" as "site
  converged"; probe the URLs instead.
- A change to `intent.yaml`'s `environments` maps to no component and
  redeploys nothing on its own. Land it with a change under `apps/web`.
- A session lives only in the visitor's cookie: nothing server-side can
  list or revoke one. Signing out clears it; changing the Worker's
  AUTH_SECRET invalidates every session at once (everyone is signed out).
- A provider's keys reach the Worker only when it deploys. After storing
  or changing one, redeploy (Deploy by hand, below); deleting an Orun
  secret does not remove it from the Worker (`wrangler secret delete`
  does).

## Secrets model

- **Brokered provider secrets**: `CLOUDFLARE_API_TOKEN` (Workers deploy
  scope: the deploy and the Worker's secrets) and `CLOUDFLARE_ACCOUNT_ID` —
  pointers minted per run from the workspace's Cloudflare connection. No
  long-lived values at rest; nothing to rotate by hand.
- **`AUTH_SECRET`** — a Worker secret on `sveltekit-auth-web-stage` and
  `-prod`, each its own, generated by that Worker's first deploy and kept
  by every later one. Never in the repository, a log or the bundle. An
  Orun secret `AUTH_SECRET` for the environment (optional) replaces it on
  the next deploy.
- **The providers' keys** — optional Orun secrets for each environment,
  `AUTH_<PROVIDER>_ID` / `_SECRET` (Auth0 adds `_ISSUER`), for the nine
  providers `apps/web/component.yaml`'s `optionalSecretEnv` lists; each
  deploy pushes the ones that are set to the Worker.
- Inspect by NAME only: `orun secrets list --org <ws> --project` and
  `--env stage|prod`, and a Worker's with `wrangler secret list --name
  sveltekit-auth-web-<env>`. No tooling in this repository prints a secret
  value, and no document in `ai/context/` may contain one.

## Verifying the system

```bash
# the site on each environment (also recorded, probed, in deployment.md)
curl -s -o /dev/null -w '%{http_code}\n' https://sveltekit-auth-web-stage.your-workers-subdomain.workers.dev/
curl -s https://sveltekit-auth-web-prod.your-workers-subdomain.workers.dev/auth/session   # null: Auth.js has its secret

# workspace readiness (integrations + repository link)
orun integrations list --org <ws> --json && orun cloud check --org <ws>
```

## Common operations

| task | how |
|---|---|
| change a page | edit `apps/web/src/routes/…`, merge |
| rename the site | edit `SITE_NAME` in `apps/web/src/site.ts`, merge |
| connect a sign-in provider | create its OAuth app (callback `<origin>/auth/callback/<provider>`), `orun secrets set AUTH_<PROVIDER>_ID --env <env>` and `…_SECRET`, then deploy by hand; the button appears on `/signin` |
| a provider not in `optionalSecretEnv` | add its keys there and to the `--secret` list in `buildCommand` (both in `apps/web/component.yaml`), or set them on the Worker with `wrangler secret put` — a Worker keeps its secrets between deploys |
| rotate AUTH_SECRET | `orun secrets set AUTH_SECRET --env <env>` with a new value, then deploy by hand; every visitor is signed out |
| deploy a change | merge to `main`; watch the run; failed lanes → `gh run rerun --failed` |
| deploy by hand | Orunbase's Deploy button, or `gh workflow run ci.yml --ref main -f environment=<env> [-f component=<a,b>]` — the named components (blank: every one) run in that environment as a merge runs them; started off `main` it is refused |
| redeploy without a change | edit the last line of `apps/web/component.yaml` (`# orun: redeploy <reason> <stamp>`) and merge — it is a deploy trigger, nothing reads it |
| serve a custom domain | attach it to the Worker in Cloudflare (README, "Custom domain"), add `<domain>/auth/callback/<provider>` to each OAuth app, then replace the placeholder `sveltekit-auth.example.com` in `intent.yaml`'s `BASE_DOMAIN` (dev, stage and prod) with it; Auth.js trusts the host it is served on |
| add a runtime secret | `orun secrets set <KEY> --org <ws> --env <env>` |
| headless credentials | `ORUN_TOKEN` (workspace-scoped) + `GITHUB_TOKEN` |

The deployment record is the bootstrap's `03-docs` phase. Re-running it (the
Orun console's Retry on that phase, or `orun new … --phase 03-docs`)
re-probes the URLs and re-renders [deployment.md](deployment.md); it is
idempotent.

## Evolution

Structural changes (a second Worker, an API, a data store — a database
adapter for Auth.js, say, to keep users and sessions server-side) follow the same
contract that deployed the site: add a component under `apps/`, `infra/` or
`packages/` with a `component.yaml`, land it as a pull request, and the
convergence run applies it.
