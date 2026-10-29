# sveltekit-auth

Auth.js's [SvelteKit example](https://github.com/nextauthjs/sveltekit-auth-example)
— a home page, a sign-in page, a page only a signed-in visitor can read and a
sign-out, over [`@auth/sveltekit`](https://authjs.dev/reference/sveltekit)
with the example's 26 OAuth providers — running on **Cloudflare Workers +
Static Assets** through SvelteKit's own
[`@sveltejs/adapter-cloudflare`](https://svelte.dev/docs/kit/adapter-cloudflare).
It is being packaged as an **Orun baseline** that takes a new site from
nothing to live on stage and prod, in its own repository, under its own
name, in ONE landing.

Sessions are the example's: Auth.js's encrypted JWT cookie, so there is no
database. Each provider is offered once its keys are stored as the site's
secrets, so the site goes live with none connected and its sign-in page
says what to connect; the AUTH_SECRET that seals the sessions is generated
on each environment's Worker by its first deploy, so nothing is typed. The
design, the milestones and the as-built status are in
[`specs/epics/sveltekit-auth`](specs/epics/sveltekit-auth/README.md).
ISC, © 2022-2024 Balázs Orbán (`apps/web/LICENSE`).

## What is here

| Surface | Where |
|---|---|
| The site's name (the home page's heading, every page's `<title>`) | `apps/web/src/site.ts` |
| `/`, `/signin` (the connected providers, or what to connect), `/protected`, `/signout` | `apps/web/src/routes` |
| Auth.js, configured per request from the Worker's secrets | `apps/web/src/auth.ts`, `apps/web/src/hooks.server.ts`, `apps/web/src/server/env.ts` |
| The 26 providers and the keys each needs | `apps/web/src/server/providers.ts` |
| The header (who is signed in) and the footer | `apps/web/src/components` |
| The deploy step that gives each Worker its secrets | `tooling/wire/worker-secrets.mjs` |
| Adapter, Worker config, deploy contract | `apps/web/svelte.config.js`, `apps/web/wrangler.jsonc`, `apps/web/component.yaml` |
| Tests (the providers, the bindings, the site's name, the secret step) | `apps/web/src/**/*.test.ts` (vitest) |

## Getting started

```bash
pnpm install          # runs `svelte-kit sync`
pnpm typecheck        # svelte-check
pnpm lint             # prettier --check
pnpm test             # vitest
pnpm build            # vite build → apps/web/.svelte-kit/cloudflare (_worker.js + the static output)
```

```bash
pnpm --filter @app/web secret:dev   # a generated AUTH_SECRET in apps/web/.env (git-ignored)
pnpm --filter @app/web dev          # http://localhost:3000
pnpm --filter @app/web preview      # wrangler dev over the built Worker
```

Both read `apps/web/.env`; `.env.example` beside it, the example's own,
lists every key the site takes. Add a provider's keys there (GitHub: an OAuth app whose
callback is `http://localhost:3000/auth/callback/github`) and its button
appears on `/signin`.

## Deploying

The Orun pipeline (`.github/workflows/ci.yml`) plans nothing while
`intent.yaml` names the placeholder workspace `ws_CHANGE_ME`. Link the
repository to an Orun Cloud workspace (`orun cloud link`), set
`execution.state.workspace` to it, connect Cloudflare in the workspace, and
every merge to `main` then deploys `sveltekit-auth-web-stage`, then
`-prod`: built, its secrets pushed to the Worker (`wrangler secret bulk`,
the AUTH_SECRET generated on the first deploy and kept after), deployed and
smoke-tested on `/` and `/auth/session`. A pull request verifies the same
lanes and deploys nothing. A manual run of `ci.yml` (Run workflow on
`main`, or Orunbase's Deploy button) redeploys the components it names —
which is how a provider's newly stored keys reach the Worker.

## Sign-in providers

None is connected at first. A provider appears once **every** key it takes
is set: `AUTH_GITHUB_ID` + `AUTH_GITHUB_SECRET` for GitHub, and the same
shape for the others (Auth0 adds `AUTH_AUTH0_ISSUER`). Deployed, they are
optional Orun secrets per environment (`orun secrets set AUTH_GITHUB_ID
--env stage`), pushed to the Worker by its next deploy; the OAuth app's
callback URL is `<origin>/auth/callback/<provider>`. The component carries
secret refs for the nine providers upstream's `.env.example` names; the
keys of every other provider are in `apps/web/src/server/providers.ts`.

## How it maps to Vercel

| The example on Vercel | Here |
|---|---|
| `@sveltejs/adapter-auto` (→ `adapter-vercel`) | `@sveltejs/adapter-cloudflare`: the Worker at `.svelte-kit/cloudflare/_worker.js`, the static output beside it (`wrangler.jsonc`) |
| `"@auth/sveltekit": "latest"` | `1.11.3`, exact; SvelteKit, Svelte and Vite at upstream's versions, exact, and upstream's `cookie@0` override |
| `AUTH_SECRET` typed into Vercel's environment variables | generated on each environment's Worker by its first deploy (`tooling/wire/worker-secrets.mjs`), kept by every later one; an Orun secret of the same name wins |
| provider keys in Vercel's environment variables, all 26 providers always registered | optional Orun secrets pushed as Worker secrets; a provider is registered only when its keys are set, and `/signin` says what to connect |
| `$env/dynamic/private` from the platform's env | the Worker's bindings (`platform.env`), read per request; `.env` locally, as upstream, for `vite dev` and `wrangler dev` alike |
| sessions: Auth.js's JWT cookie | the same; no database |
| Deploy on push | Orun deploys `<repo>-web-{stage,prod}` on merge to `main` (`apps/web/component.yaml`), smoke-tested |

## CI

| Workflow | What it runs | Ships to a site |
|---|---|---|
| `ci.yml` | the Orun pipeline, and the only workflow a site carries: `orun plan --changed`, then one job per lane. A pull request runs the verify lanes (the site built and dry-deployed per environment, no secret pushed; they do not typecheck, lint or run the tests), except the bootstrap's own landings (`orun/BASE-*`), where `plan` alone is the check; a merge deploys stage → prod. It plans nothing while `intent.yaml` names the placeholder workspace `ws_CHANGE_ME`, as this repository does. A manual run (Orunbase's Deploy button, or Run workflow on `main`) plans the environment and components it names under the push-to-main trigger, so they deploy as a merge deploys them | yes |
