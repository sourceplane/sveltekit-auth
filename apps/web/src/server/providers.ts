// Upstream's providers, each switched on by its own keys.
//
// The example registers twenty-six providers unconditionally, so a fresh
// deployment showed twenty-six buttons that all failed. Here each provider is
// listed with the keys it needs, and the Auth.js config (src/auth.ts) is
// built per request from the ones whose keys are all set: a product goes live
// with none, says so on /signin, and gains a provider the moment its keys are
// stored as Worker secrets. Auth.js itself reads `AUTH_<PROVIDER>_ID` and
// `AUTH_<PROVIDER>_SECRET` for the providers passed bare; the rest take
// their options from the same keys, as upstream wrote them.
import type { Provider } from "@auth/sveltekit/providers"
import Apple from "@auth/sveltekit/providers/apple"
import Auth0 from "@auth/sveltekit/providers/auth0"
import AzureB2C from "@auth/sveltekit/providers/azure-ad-b2c"
import BoxyHQSAML from "@auth/sveltekit/providers/boxyhq-saml"
import Cognito from "@auth/sveltekit/providers/cognito"
import Coinbase from "@auth/sveltekit/providers/coinbase"
import Discord from "@auth/sveltekit/providers/discord"
import Dropbox from "@auth/sveltekit/providers/dropbox"
import Facebook from "@auth/sveltekit/providers/facebook"
import GitHub from "@auth/sveltekit/providers/github"
import GitLab from "@auth/sveltekit/providers/gitlab"
import Google from "@auth/sveltekit/providers/google"
import Hubspot from "@auth/sveltekit/providers/hubspot"
import Keycloak from "@auth/sveltekit/providers/keycloak"
import LinkedIn from "@auth/sveltekit/providers/linkedin"
import Netlify from "@auth/sveltekit/providers/netlify"
import Okta from "@auth/sveltekit/providers/okta"
import Passage from "@auth/sveltekit/providers/passage"
import Pinterest from "@auth/sveltekit/providers/pinterest"
import Reddit from "@auth/sveltekit/providers/reddit"
import Slack from "@auth/sveltekit/providers/slack"
import Spotify from "@auth/sveltekit/providers/spotify"
import Twitch from "@auth/sveltekit/providers/twitch"
import Twitter from "@auth/sveltekit/providers/twitter"
import WorkOS from "@auth/sveltekit/providers/workos"
import Zoom from "@auth/sveltekit/providers/zoom"

export type Env = Record<string, string | undefined>

export type ProviderEntry = {
  /** Auth.js's provider id: the path segment in /auth/signin/<id>. */
  id: string
  /** What the sign-in page calls it. */
  name: string
  /** Every key that must be set for the provider to be offered. */
  keys: string[]
  /** The provider, configured from the environment. */
  make: (env: Env) => Provider
}

/** Keys of a provider Auth.js configures itself from AUTH_<ID>_ID/_SECRET. */
const pair = (prefix: string) => [`AUTH_${prefix}_ID`, `AUTH_${prefix}_SECRET`]
const triple = (prefix: string) => [...pair(prefix), `AUTH_${prefix}_ISSUER`]

// Upstream's list, in upstream's order.
export const PROVIDERS: ProviderEntry[] = [
  { id: "apple", name: "Apple", keys: pair("APPLE"), make: () => Apple },
  { id: "auth0", name: "Auth0", keys: triple("AUTH0"), make: () => Auth0 },
  {
    id: "azure-ad-b2c",
    name: "Azure AD B2C",
    keys: triple("AZURE_AD_B2C"),
    make: (env) =>
      AzureB2C({
        clientId: env.AUTH_AZURE_AD_B2C_ID,
        clientSecret: env.AUTH_AZURE_AD_B2C_SECRET,
        issuer: env.AUTH_AZURE_AD_B2C_ISSUER,
      }),
  },
  {
    id: "boxyhq-saml",
    name: "BoxyHQ SAML",
    keys: ["AUTH_BOXYHQ_SAML_ISSUER"],
    make: (env) =>
      BoxyHQSAML({
        clientId: "dummy",
        clientSecret: "dummy",
        issuer: env.AUTH_BOXYHQ_SAML_ISSUER,
      }),
  },
  {
    id: "cognito",
    name: "Cognito",
    keys: triple("COGNITO"),
    make: () => Cognito,
  },
  {
    id: "coinbase",
    name: "Coinbase",
    keys: pair("COINBASE"),
    make: () => Coinbase,
  },
  {
    id: "discord",
    name: "Discord",
    keys: pair("DISCORD"),
    make: () => Discord,
  },
  {
    id: "dropbox",
    name: "Dropbox",
    keys: pair("DROPBOX"),
    make: () => Dropbox,
  },
  {
    id: "facebook",
    name: "Facebook",
    keys: pair("FACEBOOK"),
    make: () => Facebook,
  },
  { id: "github", name: "GitHub", keys: pair("GITHUB"), make: () => GitHub },
  { id: "gitlab", name: "GitLab", keys: pair("GITLAB"), make: () => GitLab },
  { id: "google", name: "Google", keys: pair("GOOGLE"), make: () => Google },
  {
    id: "hubspot",
    name: "HubSpot",
    keys: pair("HUBSPOT"),
    make: () => Hubspot,
  },
  {
    id: "keycloak",
    name: "Keycloak",
    keys: triple("KEYCLOAK"),
    make: () => Keycloak,
  },
  {
    id: "linkedin",
    name: "LinkedIn",
    keys: pair("LINKEDIN"),
    make: () => LinkedIn,
  },
  {
    id: "netlify",
    name: "Netlify",
    keys: pair("NETLIFY"),
    make: () => Netlify,
  },
  { id: "okta", name: "Okta", keys: triple("OKTA"), make: () => Okta },
  {
    id: "passage",
    name: "Passage",
    keys: triple("PASSAGE"),
    make: () => Passage,
  },
  {
    id: "pinterest",
    name: "Pinterest",
    keys: pair("PINTEREST"),
    make: () => Pinterest,
  },
  { id: "reddit", name: "Reddit", keys: pair("REDDIT"), make: () => Reddit },
  { id: "slack", name: "Slack", keys: pair("SLACK"), make: () => Slack },
  {
    id: "spotify",
    name: "Spotify",
    keys: pair("SPOTIFY"),
    make: () => Spotify,
  },
  { id: "twitch", name: "Twitch", keys: pair("TWITCH"), make: () => Twitch },
  {
    id: "twitter",
    name: "Twitter",
    keys: pair("TWITTER"),
    make: () => Twitter,
  },
  {
    id: "workos",
    name: "WorkOS",
    keys: [...pair("WORKOS"), "AUTH_WORKOS_CONNECTION"],
    make: (env) => WorkOS({ connection: env.AUTH_WORKOS_CONNECTION! }),
  },
  { id: "zoom", name: "Zoom", keys: pair("ZOOM"), make: () => Zoom },
]

const isSet = (v: string | undefined) =>
  typeof v === "string" && v.trim() !== ""

/** The providers whose keys are all set, in upstream's order. */
export function connectedProviders(env: Env): ProviderEntry[] {
  return PROVIDERS.filter((p) => p.keys.every((k) => isSet(env[k])))
}

/** The Auth.js providers for this environment. */
export function providersFor(env: Env): Provider[] {
  return connectedProviders(env).map((p) => p.make(env))
}
