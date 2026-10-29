# sveltekit-auth — decisions

The choices that shape this repository, one line each, with where the full
reasoning lives. Superseded decisions stay listed, marked, so the history
reads in order.

| # | Decision | Why | Source |
|---|---|---|---|
| 1 | The app is nextauthjs/sveltekit-auth-example, kept close: its pages, header, footer, actions, `trustHost: true` and its 26 providers with their options | The example is what Auth.js maintains; the closer it stays, the cheaper an upgrade | design.md, "How it maps" |
| 2 | `@sveltejs/adapter-cloudflare` (one Worker + Static Assets), `nodejs_compat` | SvelteKit's own adapter, as sveltekit-boilerplate; no OpenNext | risk SU-G |
| 3 | `@auth/sveltekit` 1.11.3, SvelteKit 2.60.1, Svelte 5.55.7, Vite 6.4.2, exact; `cookie@0 → 0.7.0` carried from upstream's overrides | An unpinned `latest` would change the site under it; Auth.js peers SvelteKit `^2` | risk SU-C |
| 4 | No database: sessions are Auth.js's JWT cookies, so no D1, no db-migrate, no data rung (SU2) | The example has no adapter and persists nothing server-side | design.md, "Out of scope" |
| 5 | Each provider is registered only when every key it takes is set; with none, `/signin` says what to connect | A fresh site goes live with no provider; a button that fails is worse than none | IMPLEMENTATION-STATUS 3, 5 |
| 6 | The configuration is built per request from the Worker's bindings first, then SvelteKit's dynamic env | A provider's keys take effect with the deploy that pushes them; `wrangler dev` and `vite dev` read the same local `.env` | IMPLEMENTATION-STATUS 4 |
| 7 | AUTH_SECRET is generated once per environment on the Worker by the deploy lane (`tooling/wire/worker-secrets.mjs`: list, mint only if absent, push with `secret bulk` over stdin); a stored Orun secret wins; a failed list stops the deploy | Nothing is typed or committed, stage and prod differ, sessions survive deploys, and a live secret is never replaced by accident | design.md, "The secret flow"; risk SU-B |
| 8 | The provider keys are optional Orun secrets, kept out of the build (`env -u`) and pushed to the Worker as Worker secrets — for the nine providers upstream's `.env.example` names | They are read at request time; no bundle, build cache or log holds them; nine refs keep the component readable | risk SU-E |
| 9 | The smoke requires `</html>` on `/` and `null` from `/auth/session` | Read-only, and only a Worker with its AUTH_SECRET answers it | IMPLEMENTATION-STATUS 10 |
| 10 | The site's name is one seam, `src/site.ts`; the rename protects Auth.js's `SvelteKitAuth` import and call and the example's repository name, which contain the slug | A site keeps Auth.js's API and its credit | design.md, "The rename" |
| 11 | One landing (`01-product`) then the record (`03-docs`) | sveltekit-boilerplate's shape: one Worker, nothing to order | `docs/phases/` |
| 12 | Component docs are generated from the manifests and checked in CI | A hand-written copy drifts silently | `tooling/catalog/gen-component-docs.py` |
