import { describe, expect, it } from "vitest"
import { pageTitle, SITE_NAME } from "./site"

describe("the site's name", () => {
  it("is one non-empty literal", () => {
    expect(typeof SITE_NAME).toBe("string")
    expect(SITE_NAME.trim()).not.toBe("")
  })

  it("titles the home page with it alone, and every other page after it", () => {
    expect(pageTitle()).toBe(SITE_NAME)
    expect(pageTitle("Sign in")).toBe(`Sign in | ${SITE_NAME}`)
  })
})
