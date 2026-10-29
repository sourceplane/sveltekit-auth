import { describe, expect, it } from "vitest"
import { connectedProviders, PROVIDERS, providersFor } from "./providers"

const ids = (env: Record<string, string | undefined>) =>
  connectedProviders(env).map((p) => p.id)

describe("the sign-in providers", () => {
  it("keeps upstream's twenty-six, in upstream's order", () => {
    expect(PROVIDERS).toHaveLength(26)
    expect(PROVIDERS[0].id).toBe("apple")
    expect(PROVIDERS.at(-1)?.id).toBe("zoom")
    expect(new Set(PROVIDERS.map((p) => p.id)).size).toBe(26)
  })

  it("offers none when no key is set", () => {
    expect(ids({})).toEqual([])
    expect(providersFor({})).toEqual([])
  })

  it("offers a provider only once every key it needs is set", () => {
    expect(ids({ AUTH_GITHUB_ID: "id" })).toEqual([])
    expect(ids({ AUTH_GITHUB_ID: "id", AUTH_GITHUB_SECRET: "s" })).toEqual([
      "github",
    ])
    // Auth0 needs its issuer too.
    expect(ids({ AUTH_AUTH0_ID: "id", AUTH_AUTH0_SECRET: "s" })).toEqual([])
    expect(
      ids({
        AUTH_AUTH0_ID: "id",
        AUTH_AUTH0_SECRET: "s",
        AUTH_AUTH0_ISSUER: "https://x.auth0.com",
      }),
    ).toEqual(["auth0"])
    // WorkOS needs its connection.
    expect(ids({ AUTH_WORKOS_ID: "id", AUTH_WORKOS_SECRET: "s" })).toEqual([])
  })

  it("treats a blank key as unset", () => {
    expect(ids({ AUTH_GITHUB_ID: "  ", AUTH_GITHUB_SECRET: "s" })).toEqual([])
  })

  it("lists several in upstream's order, not the environment's", () => {
    const env = {
      AUTH_GOOGLE_ID: "g",
      AUTH_GOOGLE_SECRET: "g",
      AUTH_DISCORD_ID: "d",
      AUTH_DISCORD_SECRET: "d",
      AUTH_GITHUB_ID: "h",
      AUTH_GITHUB_SECRET: "h",
    }
    expect(ids(env)).toEqual(["discord", "github", "google"])
    expect(providersFor(env)).toHaveLength(3)
  })

  it("configures the providers upstream configured from the environment", () => {
    const [b2c] = providersFor({
      AUTH_AZURE_AD_B2C_ID: "b2c-id",
      AUTH_AZURE_AD_B2C_SECRET: "b2c-secret",
      AUTH_AZURE_AD_B2C_ISSUER: "https://tenant.b2clogin.com/x/v2.0/",
    }) as unknown as { options: Record<string, string> }[]
    expect(b2c.options.clientId).toBe("b2c-id")
    expect(b2c.options.issuer).toBe("https://tenant.b2clogin.com/x/v2.0/")
  })
})
