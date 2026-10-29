import { SvelteKitAuth } from "@auth/sveltekit"
import { serverEnv } from "./server/env"
import { providersFor } from "./server/providers"

// Upstream's Auth.js configuration, made lazy: the providers are read per
// request from the Worker's own secrets, so a provider whose keys are stored
// appears on the next request after the deploy that pushed them, and one
// with no keys is never offered. Sessions are Auth.js's default, an
// encrypted JWT cookie sealed with AUTH_SECRET; there is no database.
export const { handle, signIn, signOut } = SvelteKitAuth(async (event) => {
  const env = serverEnv(event)
  return {
    trustHost: true,
    secret: env.AUTH_SECRET,
    providers: providersFor(env),
  }
})
