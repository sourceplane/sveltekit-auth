# apps/web — the site

Auth.js's [SvelteKit example](https://github.com/nextauthjs/sveltekit-auth-example)
(ISC, © 2022-2024 Balázs Orbán, `LICENSE` beside this file) on SvelteKit 2
and Svelte 5, running on Cloudflare Workers + Static Assets through
[`@sveltejs/adapter-cloudflare`](https://svelte.dev/docs/kit/adapter-cloudflare):

- `/` — the home page; the header says who is signed in, with a sign-in or
  sign-out button
- `/signin` — a button per connected provider, or, with none connected,
  what to connect; its form action is upstream's, Auth.js's `signIn`
- `/protected` — its content only for a signed-in visitor, "Access Denied"
  for anyone else
- `/signout` — upstream's action, Auth.js's `signOut`
- `/auth/*` — Auth.js's own routes (`/auth/session`, `/auth/providers`,
  `/auth/callback/<provider>`, …), answered by the handle in
  `src/hooks.server.ts`

Auth.js is configured per request (`src/auth.ts`) from the Worker's own
secrets: `AUTH_SECRET` seals the session cookie, and each provider in
`src/server/providers.ts` is offered only when every key it takes is set.
The site's name — the home page's heading and every page's `<title>` — is
in `src/site.ts`.

```bash
pnpm secret:dev # a generated AUTH_SECRET in .env (kept on a second run)
pnpm dev        # vite dev on http://localhost:3000, reading .env
pnpm build      # vite build → .svelte-kit/cloudflare (_worker.js + the static output)
pnpm preview    # wrangler dev over the built Worker
pnpm test       # vitest
```

How it is deployed — per environment, on merge to `main`, its secrets
pushed to the Worker first — is the repository's README and
`component.yaml` beside this file.
