# Epic: sveltekit-auth (SU)

**Auth.js already runs on Workers: `@auth/core` is built on Web APIs, and `@auth/sveltekit` is a SvelteKit `handle`. What the example needs from Cloudflare is an adapter, a secret and somewhere to keep a provider's keys. The port swaps `adapter-auto` for `@sveltejs/adapter-cloudflare`, keeps the example's pages and its 26 providers, offers each provider only once its keys are stored as the site's secrets, and has the deploy generate the AUTH_SECRET on each environment's Worker instead of asking anybody to type one. Sessions are the example's: Auth.js's encrypted JWT cookie, no database — so there is no data rung (SU2) to build.**

The port keeps the home page, the header (who is signed in, a sign-in or
sign-out button), the footer, the protected page, the sign-in and sign-out
actions and the example's providers with their options. It adds a sign-in
page that lists the connected providers or says what to connect, the
per-request configuration, the Workers build, the secret step in the deploy,
the monorepo wrapper, tests and the deploy contract.

## Status

| Field | Value |
|-------|-------|
| Status | ✅ Shipped (`baseline-v1`) — SU0 (#1), SU1 (#2), SU3 (#3), SU4 (#4); proven offline in Baseline CI; not yet live (risk SU-A) |
| Cluster | **SU** (SU0, SU1, SU3, SU4; SU2, the data rung, is not needed) |
| Owner(s) | `apps/web` · `tooling/wire/worker-secrets.mjs` |
| Builds on | `sveltekit-boilerplate`: its scaffolding, its adapter-cloudflare build and its one-landing blueprint; the reference starters' `worker-secrets.mjs` |
| Upstream | [nextauthjs/sveltekit-auth-example](https://github.com/nextauthjs/sveltekit-auth-example) (ISC, © 2022-2024 Balázs Orbán), at `879b182` |
| Changes | adapter-cloudflare, exact pins, providers offered by their keys, a sign-in page, the generated AUTH_SECRET, tests and the deploy contract |
| Gate | SU1 is the first user-visible rung. |

## Read order

1. `design.md` — what maps to what, the secret flow, what is out of scope
2. `implementation-plan.md` — the milestones and what "done" means for each
3. `risks-and-open-questions.md` — what could go wrong and what was decided
4. `IMPLEMENTATION-STATUS.md` — what actually shipped (kept distinct from intent)

## Milestones at a glance

| Milestone | What it lands | Done when |
|---|---|---|
| SU0 — the spec | intent, CI, tooling, the spec index, this doc set and the task contracts | merged on `main` |
| SU1 — the auth app on Workers | `apps/web`, `tooling/wire/worker-secrets.mjs` | `wrangler dev` serves every page; a GitHub sign-in reaches GitHub's authorize URL |
| SU2 — the data | nothing: JWT sessions persist nothing server-side | — (not needed) |
| SU3 — ready to instantiate | README, as-built status | a reader can run, test, preview and deploy it and connect a provider |
| SU4 — a baseline | card, build document, rename, bootstrap tooling, tests | a new site goes from nothing to live in one landing; Baseline CI green |
