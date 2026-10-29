# web — architecture

Built by the turbo pipeline from `apps/web` and deployed with wrangler.

|                     |                                     |
| ------------------- | ----------------------------------- |
| Worker config       | `apps/web/wrangler.jsonc`           |
| Entry               | `.svelte-kit/cloudflare/_worker.js` |
| Compatibility date  | `2026-10-01`                        |
| Compatibility flags | `nodejs_compat`                     |

## Bindings

| Binding  | Kind          | Source                   |
| -------- | ------------- | ------------------------ |
| `ASSETS` | Static assets | `.svelte-kit/cloudflare` |

## Secrets resolved by the lane (names only)

- `AUTH_AUTH0_ID` (optional)
- `AUTH_AUTH0_ISSUER` (optional)
- `AUTH_AUTH0_SECRET` (optional)
- `AUTH_DISCORD_ID` (optional)
- `AUTH_DISCORD_SECRET` (optional)
- `AUTH_FACEBOOK_ID` (optional)
- `AUTH_FACEBOOK_SECRET` (optional)
- `AUTH_GITHUB_ID` (optional)
- `AUTH_GITHUB_SECRET` (optional)
- `AUTH_GOOGLE_ID` (optional)
- `AUTH_GOOGLE_SECRET` (optional)
- `AUTH_LINKEDIN_ID` (optional)
- `AUTH_LINKEDIN_SECRET` (optional)
- `AUTH_PINTEREST_ID` (optional)
- `AUTH_PINTEREST_SECRET` (optional)
- `AUTH_SECRET` (optional)
- `AUTH_TWITCH_ID` (optional)
- `AUTH_TWITCH_SECRET` (optional)
- `AUTH_TWITTER_ID` (optional)
- `AUTH_TWITTER_SECRET` (optional)
