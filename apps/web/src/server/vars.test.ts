import { describe, expect, it } from "vitest"
import { workerVars } from "./vars"

describe("workerVars", () => {
  it("is SvelteKit's dynamic env when there are no bindings", () => {
    expect(workerVars({ AUTH_SECRET: "a" })).toEqual({ AUTH_SECRET: "a" })
  })

  it("lets the Worker's own bindings win (the local .env, under vite dev)", () => {
    expect(
      workerVars(
        { AUTH_SECRET: "from-env", OTHER: "x" },
        { AUTH_SECRET: "from-binding" },
      ),
    ).toEqual({ AUTH_SECRET: "from-binding", OTHER: "x" })
  })

  it("takes only strings: a service binding is not a variable", () => {
    const vars = workerVars(
      {},
      { ASSETS: { fetch() {} }, AUTH_GITHUB_ID: "id" },
    )
    expect(vars).toEqual({ AUTH_GITHUB_ID: "id" })
  })
})
