# Implementation status — sveltekit-auth

| Milestone | Status | Shipped in |
|---|---|---|
| SU0 — the spec | ✅ Shipped | [#1](https://github.com/sourceplane/sveltekit-auth/pull/1) |
| SU1 — the auth app on Workers | ✅ Shipped | [#2](https://github.com/sourceplane/sveltekit-auth/pull/2) |
| SU2 — the data | Not needed: JWT sessions persist nothing | — |
| SU3 — ready to instantiate | In progress |  |
| SU4 — a baseline | Not started |  |

## What is proven, and how

| Claim | Proven by |
|---|---|
| The app builds into one Worker with Static Assets (702 KiB, 162 KiB gzipped) | `pnpm build` + `wrangler deploy --dry-run` |
| The providers and their keys (all 26, in upstream's order; a blank key is no key; Auth0 needs its issuer, WorkOS its connection), the bindings winning over the dynamic env, the site's name | `apps/web/src/server/*.test.ts`, `apps/web/src/site.test.ts` |
| The secret step: a verify lane pushes nothing; a first deploy mints a 43-character key that appears in no argument and no log; an existing key is kept; a failed list refuses; a stored key is used as is; the local `.env` is merged, 0600 | `apps/web/src/worker-secrets.test.ts`, against a stand-in `wrangler` |
| Served by `wrangler dev` and `vite dev`: with no AUTH_SECRET `/auth/session` fails; with one every page renders, `/auth/session` is null, `/signin` says what to connect and its post goes back there, `/protected` denies; with GitHub's keys `/signin` offers GitHub and its post is GitHub's authorize URL with this site's callback; a session cookie sealed with the secret opens `/protected`; sign-out clears it | by hand (SU1); Baseline CI's end-to-end tier, next (SU4) |
| The secret push and the deploy on a real account | only a live bootstrap (risk SU-A) |

## Departures from the upstream example

1. **`@sveltejs/adapter-cloudflare`** in place of `adapter-auto`, with `wrangler.jsonc` (`nodejs_compat`, the assets binding, observability) and the upstream aliases kept.
2. **Exact pins** — `@auth/sveltekit@1.11.3` (upstream: `latest`), SvelteKit `2.60.1`, Svelte `5.55.7`, Vite `6.4.2`, `@sveltejs/vite-plugin-svelte` `5.1.1` (upstream's floors, exact). Of upstream's pnpm overrides only `cookie@0 → 0.7.0` is still needed (`pnpm-workspace.yaml`); the rest are floors the lockfile resolves above. SvelteKit stays on 2: `@auth/sveltekit` peers `^1 || ^2`.
3. **Providers by their keys** (`src/server/providers.ts`): the same 26, in upstream's order, with upstream's options for Azure AD B2C, BoxyHQ SAML and WorkOS; each registered only when every key it takes is set. Upstream registers all 26, so a fresh deployment showed 26 buttons that failed.
4. **The configuration is lazy** (`SvelteKitAuth(async (event) => …)`, `src/auth.ts`) and reads the Worker's bindings first (`src/server/env.ts`), so a provider's keys take effect with the deploy that pushes them, and `vite dev` and `wrangler dev` read the same `.env`.
5. **A `/signin` page**: one button per connected provider (Auth.js's `SignIn` component, posting to upstream's action), or, with none, the notice, GitHub's keys, and every provider's keys. The action sends a visitor back to it when nothing is connected.
6. **AUTH_SECRET is generated** on each environment's Worker by the deploy (`tooling/wire/worker-secrets.mjs`) and kept by every later one; an Orun secret of the same name wins. Locally, `pnpm secret:dev` writes one into `.env`.
7. **`<title>`s and the site's name** (`src/site.ts`): the home page's heading is the site's name; every page has a title.
8. **The footer's `/policy` link is dropped**: upstream links a page it does not have.
9. `.env.example` is upstream's, its comments added; `.env` is the local file for `vite dev` and `wrangler dev` alike (wrangler reads `.env` when there is no `.dev.vars`). `vite.config.js` becomes `vite.config.ts` with vitest's config. Upstream's ESLint 8 config is not carried (it had no lint script); `pnpm lint` is upstream's Prettier config, checked.
10. **Tests**, the monorepo wrapper and the deploy contract are new. The smoke reads `/` and `/auth/session`, read-only.
11. Kept as upstream wrote it: the signed-out avatar from `api.dicebear.com` (risk SU-F), the footer's links, `trustHost: true`.
