# Risks and open questions — sveltekit-auth

| # | Risk | Mitigation / decision |
|---|---|---|
| SU-A | The deploy on a real account is proven only by a live bootstrap: the brokered token's reach over Worker secrets, `secret bulk` creating the Worker on a first deploy, the smoke on workers.dev. | Baseline CI runs the deploy lane's own build step (the secret step as a verify lane runs it), dry-deploys, and serves the built Worker under `wrangler dev` through every page, with and without its secret and with a provider. The secret step's deploy path runs against a stand-in `wrangler` in `src/worker-secrets.test.ts`. OPEN until a bootstrap. |
| SU-B | `wrangler secret list` fails for a reason other than a missing Worker (a revoked token, an API outage). Minting then would replace a live AUTH_SECRET and sign everybody out. | The step stops and pushes nothing ("refusing to mint a replacement"); the deploy fails loudly and the Worker keeps its secret. ACCEPTED: a failed deploy beats a silent sign-out. |
| SU-C | `@auth/sveltekit` is 1.x over `@auth/core` 0.41 — Auth.js's v5 line, whose APIs still move between minors. | Pinned exactly (`1.11.3`); an upgrade is a deliberate change: bump, re-run the e2e. ACCEPTED. |
| SU-D | JWT sessions cannot be listed or revoked server-side; rotating AUTH_SECRET signs everybody out. | The example's design, kept (design.md, "Out of scope"). A database adapter is the owner's change. ACCEPTED. |
| SU-E | Only the nine providers upstream's `.env.example` names have Orun secret refs; the other seventeen need two edits to `component.yaml`, or `wrangler secret put`, to deploy. | A readable card and component over sixty refs nobody sets; the README and operations page say how. ACCEPTED. |
| SU-F | The header's signed-out avatar is upstream's random image from `api.dicebear.com`: a third-party request from the visitor's browser (and a value that differs between the server render and hydration). | Upstream's look, kept. ACCEPTED; noted in IMPLEMENTATION-STATUS. |
| SU-G | `nodejs_compat`: the adapter's Worker uses `AsyncLocalStorage`. | As sveltekit-boilerplate. ACCEPTED. |
