# Implementation plan — sveltekit-auth

| Milestone | Task | What lands | Done when |
|---|---|---|---|
| SU0 — the spec | SU-1 | intent (`ws_CHANGE_ME`), `ci.yml` (sveltekit-boilerplate's, byte for byte), shared tooling, the spec index, this doc set, the task contracts | merged; CI's plan job green |
| SU1 — the auth app on Workers | SU-2 | `apps/web` — the example on adapter-cloudflare, exact pins, providers by their keys, `/signin`, the per-request configuration; `tooling/wire/worker-secrets.mjs` and the deploy contract | typecheck, lint, test and build green; under `wrangler dev`, no secret → `/auth/session` fails; a secret → every page renders and `/auth/session` is null; GitHub's keys → the button and GitHub's authorize URL |
| SU2 — the data | — | nothing: the example's sessions are JWT cookies and persist nothing | not needed |
| SU3 — ready to instantiate | SU-3 | the README, the as-built status | a reader can run, test, preview and deploy it and connect a provider |
| SU4 — a baseline | SU-4 | `blueprint.yaml`, `repo-blueprint.yaml`, `.baseline/`, the rename and bootstrap tooling, the context pack, the component docs, `testing/`, `baseline.yml`, `tag.yml` | Baseline CI green; `baseline-v1` cut by `tag.yml` |
