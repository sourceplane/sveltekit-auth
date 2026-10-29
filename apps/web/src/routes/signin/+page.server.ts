import { redirect } from "@sveltejs/kit"
import { signIn } from "../../auth"
import { serverEnv } from "../../server/env"
import { connectedProviders, PROVIDERS } from "../../server/providers"
import type { Actions, PageServerLoad } from "./$types"

// GET /signin: which providers this deployment offers, and — when it offers
// none — the keys each one needs, so the page can say what to connect.
export const load: PageServerLoad = async (event) => {
  const connected = connectedProviders(serverEnv(event)).map(
    ({ id, name }) => ({
      id,
      name,
    }),
  )
  return {
    connected,
    available: PROVIDERS.map(({ id, name, keys }) => ({ id, name, keys })),
  }
}

// POST /signin is upstream's action (the header's Sign in button): Auth.js
// sends the visitor to its sign-in page, or straight to a provider when the
// form names one. With no provider connected there is nothing to send them to,
// so they land on this route's own page, which says how to connect one.
export const actions = {
  default: async (event) => {
    if (connectedProviders(serverEnv(event)).length === 0)
      redirect(303, "/signin")
    return signIn(event)
  },
} satisfies Actions
