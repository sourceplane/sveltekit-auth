# sveltekit-auth

A SvelteKit site whose sign-in is [Auth.js](https://authjs.dev) — a home
page, a sign-in page, a page only a signed-in visitor can read, and a
sign-out — on **Cloudflare Workers + Static Assets** through SvelteKit's own
[`@sveltejs/adapter-cloudflare`](https://svelte.dev/docs/kit/adapter-cloudflare).
Sessions are Auth.js's encrypted JWT cookies: there is no database to run.

It is Auth.js's SvelteKit example, ported to Cloudflare.
Upstream: https://github.com/nextauthjs/sveltekit-auth-example (ISC,
© 2022-2024 Balázs Orbán; the licence is `apps/web/LICENSE`).

## Live deployment

<!-- 03-docs:begin -->
Not recorded yet. The bootstrap's last phase writes the live URLs, the
workspace and the secrets the site uses into
[ai/context/deployment.md](ai/context/deployment.md); how the site deploys
and how to operate it is in
[ai/context/operations.md](ai/context/operations.md).
<!-- 03-docs:end -->

## What is here

| Surface | Where |
|---|---|
| The site's name (the home page's heading, every page's `<title>`) | `apps/web/src/site.ts` |
| `/` (home), `/signin`, `/protected`, `/signout` | `apps/web/src/routes` |
| Auth.js: the configuration, built per request from the Worker's secrets | `apps/web/src/auth.ts`, `apps/web/src/hooks.server.ts` |
| The 26 sign-in providers and the keys each needs | `apps/web/src/server/providers.ts` |
| The header (who is signed in, sign in and out) and the footer | `apps/web/src/components` |
| The deploy step that gives each Worker its secrets | `tooling/wire/worker-secrets.mjs` |
| Workers build and deploy contract | `apps/web/svelte.config.js`, `apps/web/wrangler.jsonc`, `apps/web/component.yaml` |
| Tests (the providers and their keys, the site's name, the secrets step) | `apps/web/src/**/*.test.ts` (vitest) |

## Getting started

```bash
pnpm install          # runs `svelte-kit sync`
pnpm typecheck        # svelte-check
pnpm lint             # prettier --check
pnpm test             # vitest
pnpm build            # vite build → apps/web/.svelte-kit/cloudflare (_worker.js + the static output)
```

```bash
pnpm --filter @app/web secret:dev   # writes a generated AUTH_SECRET into apps/web/.env (git-ignored)
pnpm --filter @app/web dev          # http://localhost:3000
pnpm --filter @app/web preview      # wrangler dev over the built Worker, http://localhost:8787
```

Both read `apps/web/.env`: copy `apps/web/.env.example`, the example's
own, for every key the site can take. Without an
AUTH_SECRET Auth.js refuses every request with a server-configuration
error, so run `secret:dev` once; a second run keeps the secret it wrote.

Make the site yours in `apps/web/src/routes` (the pages) and
`apps/web/src/site.ts` (its name). A page reads the visitor's session from
`$page.data.session` (the root layout loads it with `event.locals.auth()`),
as `/protected` does.

## Sign-in providers

The site deploys with no provider connected, and `/signin` says so and
lists what each one needs. A provider is offered once **every** key it
takes is set; the others are never shown. For GitHub:

1. Create an OAuth app (GitHub → Settings → Developer settings → OAuth
   Apps). Its callback URL is the site's `/auth/callback/github`:
   `https://sveltekit-auth-web-prod.<subdomain>.workers.dev/auth/callback/github`
   for prod (one app per environment, or one per origin you serve).
2. Store its client id and secret as this repository's Orun secrets for
   that environment (or on the console's Secrets page):

   ```bash
   orun secrets set AUTH_GITHUB_ID --env prod       # prompts for the value
   orun secrets set AUTH_GITHUB_SECRET --env prod
   ```

   The build never sees them; the deploy hands them to the Worker as
   Worker secrets (`wrangler secret bulk`, over stdin), so they are in no
   bundle, no build cache and no log.
3. Redeploy (a merge, or **Deploy by hand** below). The deploy pushes the
   keys to the Worker, and the GitHub button appears.

The deploy pushes the keys of the providers upstream's `.env.example`
names, when they are set:

| Provider | Keys |
|---|---|
| GitHub | `AUTH_GITHUB_ID`, `AUTH_GITHUB_SECRET` |
| Google | `AUTH_GOOGLE_ID`, `AUTH_GOOGLE_SECRET` |
| Discord | `AUTH_DISCORD_ID`, `AUTH_DISCORD_SECRET` |
| LinkedIn | `AUTH_LINKEDIN_ID`, `AUTH_LINKEDIN_SECRET` |
| Facebook | `AUTH_FACEBOOK_ID`, `AUTH_FACEBOOK_SECRET` |
| Twitter | `AUTH_TWITTER_ID`, `AUTH_TWITTER_SECRET` |
| Twitch | `AUTH_TWITCH_ID`, `AUTH_TWITCH_SECRET` |
| Pinterest | `AUTH_PINTEREST_ID`, `AUTH_PINTEREST_SECRET` |
| Auth0 | `AUTH_AUTH0_ID`, `AUTH_AUTH0_SECRET`, `AUTH_AUTH0_ISSUER` |

The other seventeen of the example's providers (Apple, Azure AD B2C, BoxyHQ
SAML, Cognito, Coinbase, Dropbox, GitLab, HubSpot, Keycloak, Netlify, Okta,
Passage, Reddit, Slack, Spotify, WorkOS, Zoom) work the same way; their keys
are in `apps/web/src/server/providers.ts`. Set them in `apps/web/.env` locally.
To deploy one, add its keys to `optionalSecretEnv` in
`apps/web/component.yaml` and to the `--secret` list in that file's
`buildCommand`, or set them on the Worker directly
(`pnpm --filter @app/web exec wrangler secret put AUTH_GITLAB_ID --name sveltekit-auth-web-prod`):
a Worker keeps its secrets from one deploy to the next.

## Sessions and AUTH_SECRET

A session is Auth.js's default: a JWT, encrypted with `AUTH_SECRET`, in an
httpOnly `authjs.session-token` cookie (`__Secure-` prefixed over HTTPS).
Nothing about a visitor is stored anywhere else. The upstream example has
no database adapter, and none is added.

Each environment's Worker gets its own AUTH_SECRET from its first deploy:
the deploy lane's build step (`tooling/wire/worker-secrets.mjs`) lists the
secrets the Worker carries, generates one only if it carries none, and
pushes it with `wrangler secret bulk` over stdin. Every later deploy keeps
it, so sessions survive deploys. It is never in the repository, a log or
the build. To set your own, store an Orun secret named `AUTH_SECRET` for
the environment (`orun secrets set AUTH_SECRET --env prod`); the next deploy
pushes it. Changing it signs everyone out,
since a session sealed with the old secret no longer opens.

## How it deploys

Merges to `main` converge through Orun: `.github/workflows/ci.yml` plans the
changed components and runs each lane against the workspace in
`intent.yaml`. The site deploys to `stage`, then to `prod` once stage has
converged on the same commit; `dev` only verifies. The Worker is
`sveltekit-auth-web-<env>` on your account's workers.dev subdomain. Each
deploy builds the site, gives the Worker its secrets, deploys it, and is
smoke-tested over HTTP: the home page must render and Auth.js's
`/auth/session` must answer `null`, which it does only once the Worker has
its AUTH_SECRET. A pull request runs the same pipeline's verify lanes: the
site built and dry-deployed for each environment, with nothing deployed and
no secret pushed. They do not lint or run the tests, so run
`pnpm typecheck`, `pnpm lint` and `pnpm test` before you push.

The pipeline holds one credential, GitHub's own `GITHUB_TOKEN`. The
Cloudflare token and account id are brokered per run from the workspace's
Cloudflare connection; the providers' keys are the site's own secrets in
the workspace. Nothing provider-shaped is stored in the repository or in
GitHub.

**Deploy by hand.** Orunbase's **Deploy** button on a component, or **Run
workflow** on the CI workflow in GitHub's Actions tab (on `main`), runs
`ci.yml` for the environment and components you pick, and each one deploys
exactly as a merge would deploy it. Leave the component blank to redeploy
every component in that environment, with nothing changed: after storing a
provider's keys, say. A component with nothing to run in that environment
(a test suite in `prod`) is left out with a notice.

## Custom domain

The site answers on workers.dev from its first deploy. To serve it on your
own domain, add the domain to the Cloudflare account the site deploys into
and attach it to the Worker (dashboard → Workers & Pages →
`sveltekit-auth-web-prod` → Settings → Domains & Routes → Add → Custom
domain). Do the same for stage with a subdomain if you want one.

Auth.js trusts the host a request arrives on (`trustHost: true`), so
sign-in works on the new origin with no change to the code: add the new
origin's `/auth/callback/<provider>` to each OAuth app. The repository
names the domain in one place, `BASE_DOMAIN` in `intent.yaml` (dev, stage
and prod), which the site was born with as the reserved placeholder
`sveltekit-auth.example.com`. Replace it with your domain in the same
change that records it.
