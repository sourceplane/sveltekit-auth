# Design — sveltekit-auth

## What the example is

nextauthjs/sveltekit-auth-example, maintained from the next-auth monorepo's
`apps/examples/sveltekit`: a SvelteKit app whose `src/auth.ts` calls
`SvelteKitAuth({ trustHost: true, providers: [...] })` from `@auth/sveltekit`
with 26 OAuth providers — Apple, Auth0, Azure AD B2C, BoxyHQ SAML, Cognito,
Coinbase, Discord, Dropbox, Facebook, GitHub, GitLab, Google, HubSpot,
Keycloak, LinkedIn, Netlify, Okta, Passage, Pinterest, Reddit, Slack,
Spotify, Twitch, Twitter, WorkOS, Zoom — most passed bare, so Auth.js reads
`AUTH_<PROVIDER>_ID` and `AUTH_<PROVIDER>_SECRET` itself.

- `src/hooks.server.ts` exports Auth.js's `handle`, which answers
  `/auth/*` (sign-in, callback, session, providers, sign-out) and puts
  `locals.auth()` on every request;
- `src/routes/+layout.server.ts` loads the session for every page;
- `/` is a paragraph, `/protected` shows its content only with a session,
  `/signin` and `/signout` are form actions — Auth.js's `signIn` and
  `signOut`;
- the header shows the visitor's avatar and email with a sign-out button,
  or a sign-in button; the footer links Auth.js's docs and npm.

There is no database adapter, so a session is Auth.js's default: a JWT,
encrypted with `AUTH_SECRET` (A256CBC-HS512, the key derived with HKDF), in
an httpOnly cookie. Nothing about a visitor is stored server-side.

## How it maps

| Upstream | Here |
|---|---|
| `@sveltejs/adapter-auto` (Vercel at deploy) | `@sveltejs/adapter-cloudflare` 7.2.9: the Worker at `.svelte-kit/cloudflare/_worker.js`, the static output beside it, `wrangler.jsonc` naming both; `nodejs_compat` |
| `"@auth/sveltekit": "latest"` | `1.11.3`, exact (on `@auth/core` 0.41.3) |
| SvelteKit `^2.60.1`, Svelte `^5.55.7`, Vite `^6.4.2`, and the example's overrides | the same versions, exact; of the overrides only `cookie@0 → 0.7.0` is still below the lockfile, so `pnpm-workspace.yaml` carries it |
| `SvelteKitAuth({...})`, every provider registered | `SvelteKitAuth(async (event) => ({...}))`: built per request from the Worker's variables (`src/server/env.ts`), each provider in `src/server/providers.ts` registered only when every key it takes is set |
| `$env/dynamic/private` | the Worker's bindings first (`platform.env`), then SvelteKit's dynamic env; locally both come from `.env`, which `vite dev` and `wrangler dev` read |
| `.env` with `AUTH_SECRET` typed in | deployed: a Worker secret the deploy generates once per environment (`tooling/wire/worker-secrets.mjs`); locally: still `.env`, written by `pnpm secret:dev` |
| `.env` with provider keys | optional Orun secrets per environment (`apps/web/component.yaml`'s `optionalSecretEnv`), pushed to the Worker as Worker secrets by the deploy; `.env` locally |
| no `/signin` page (the action posts to Auth.js's built-in page) | `/signin` lists the connected providers, one button each, or says no provider is connected and which keys connect each; the action sends a visitor with nothing to sign in with back to it |
| `vite.config.js` | `vite.config.ts` with vitest's config (the tests) |
| Vercel's "Deploy" button | `orun new --blueprint repo-blueprint.yaml` — a new repository, branded, deployed |

## The secret flow

```
deploy lane (per environment, CLOUDFLARE_API_TOKEN bound)
  build-app:  env -u AUTH_* … vite build                       (no secret in the build)
              node tooling/wire/worker-secrets.mjs --worker <repo>-web-<env>
                ├─ wrangler secret list --name <repo>-web-<env> --format json
                │     "does not exist" (10007) → it carries nothing
                │     any other failure        → stop: never mint a replacement
                ├─ AUTH_SECRET: the stored Orun secret if there is one,
                │               else kept if the Worker has one,
                │               else randomBytes(32), base64url
                └─ wrangler secret bulk (JSON on stdin): AUTH_SECRET if new or stored,
                                                         every provider key that is set
  deploy:     wrangler deploy                                    (the Worker keeps its secrets)
  smoke:      GET /  → </html>;  GET /auth/session → null        (only with AUTH_SECRET)
verify lane (pull request; no Cloudflare credential): worker-secrets names the keys, pushes nothing
```

On a first deploy the Worker does not exist yet: `secret bulk` creates it
(wrangler's draft Worker) with its secrets, and `wrangler deploy` then
uploads the real script over it.

## The rename

The baseline's slug is `sveltekit-auth` and its Pascal form `SvelteKitAuth`
— which is also Auth.js's own export, and `sveltekit-auth-example` the
upstream repository. The rename protects those three (`UPSTREAM` in
`tooling/rebrand/rebrand.mjs`: the import, the call, the repository and its
Vercel demo) and renames every other form; `testing/rebrand.test.sh` and
`testing/placement.test.sh` prove a site keeps Auth.js's names.

## Out of scope

- A database adapter (users, accounts and sessions server-side): the
  example has none. A session cannot be listed or revoked; changing
  AUTH_SECRET signs everybody out.
- Providers that need an adapter: email and magic links (Nodemailer,
  Resend), WebAuthn passkeys. Credentials sign-in: the example has none.
- Custom domains: the Worker goes live on workers.dev.
