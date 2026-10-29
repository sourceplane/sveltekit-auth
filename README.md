# sveltekit-auth

An Orunbase starter baseline, being built: Auth.js's [SvelteKit example](https://github.com/nextauthjs/sveltekit-auth-example)
on Cloudflare Workers + Static Assets through
[`@sveltejs/adapter-cloudflare`](https://svelte.dev/docs/kit/adapter-cloudflare),
on the Cirrus baseline conventions. ISC, © 2022-2024 Balázs Orbán
(`apps/web/LICENSE`).

Upstream: https://github.com/nextauthjs/sveltekit-auth-example

## Running it

```bash
pnpm install
pnpm typecheck && pnpm lint && pnpm test && pnpm build
pnpm --filter @app/web secret:dev   # a generated AUTH_SECRET in apps/web/.env (git-ignored)
pnpm --filter @app/web dev          # http://localhost:3000
pnpm --filter @app/web preview      # wrangler dev over the built Worker
```

A sign-in provider appears on `/signin` once its keys are in
`apps/web/.env` (`.env.example` lists them). The plan and the as-built
status are the epic in
[`specs/epics/sveltekit-auth`](specs/epics/sveltekit-auth/README.md).
