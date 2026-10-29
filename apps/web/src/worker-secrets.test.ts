// tooling/wire/worker-secrets.mjs, the step that hands the Worker its secrets
// and mints AUTH_SECRET, run against a stand-in `pnpm` that records what it
// was asked and answers `wrangler secret list` as each case says.
import { spawnSync } from "node:child_process"
import {
  chmodSync,
  mkdtempSync,
  readFileSync,
  writeFileSync,
  existsSync,
} from "node:fs"
import { tmpdir } from "node:os"
import { join, resolve } from "node:path"
import { describe, expect, it } from "vitest"

const SCRIPT = resolve(__dirname, "../../../tooling/wire/worker-secrets.mjs")

type Run = {
  status: number | null
  out: string
  calls: string[]
  bulk: Record<string, string> | null
}

function run(
  argv: string[],
  env: Record<string, string>,
  list: { status: number; out: string },
): Run {
  const dir = mkdtempSync(join(tmpdir(), "worker-secrets-"))
  const shim = join(dir, "pnpm")
  writeFileSync(
    shim,
    `#!/usr/bin/env bash
echo "$*" >> "${dir}/calls"
if [ "$3" = "secret" ] && [ "$4" = "list" ]; then printf '%s' "$LIST_OUT"; exit $LIST_STATUS; fi
if [ "$3" = "secret" ] && [ "$4" = "bulk" ]; then cat > "${dir}/bulk"; exit 0; fi
exit 9
`,
  )
  chmodSync(shim, 0o755)
  const r = spawnSync("node", [SCRIPT, ...argv], {
    encoding: "utf8",
    env: {
      PATH: `${dir}:${process.env.PATH}`,
      LIST_OUT: list.out,
      LIST_STATUS: String(list.status),
      ...env,
    },
  })
  const calls = existsSync(join(dir, "calls"))
    ? readFileSync(join(dir, "calls"), "utf8").trim().split("\n")
    : []
  const bulk = existsSync(join(dir, "bulk"))
    ? JSON.parse(readFileSync(join(dir, "bulk"), "utf8"))
    : null
  return { status: r.status, out: r.stdout + r.stderr, calls, bulk }
}

const deploy = [
  "--worker",
  "acme-web-stage",
  "--config",
  "wrangler.jsonc",
  "--generate",
  "AUTH_SECRET",
  "--secret",
  "AUTH_GITHUB_ID",
  "--secret",
  "AUTH_GITHUB_SECRET",
]
const token = { CLOUDFLARE_API_TOKEN: "t" }
const listing = (names: string[]) => ({
  status: 0,
  out: JSON.stringify(names.map((name) => ({ name, type: "secret_text" }))),
})

describe("worker-secrets", () => {
  it("pushes nothing from a verify lane (no Cloudflare credential)", () => {
    const r = run(deploy, { AUTH_GITHUB_ID: "id" }, listing([]))
    expect(r.status).toBe(0)
    expect(r.calls).toEqual([])
    expect(r.out).toMatch(/verify lane/)
  })

  it("mints AUTH_SECRET on the first deploy, with the providers' keys that are set", () => {
    const r = run(
      deploy,
      { ...token, AUTH_GITHUB_ID: "id", AUTH_GITHUB_SECRET: "s" },
      {
        status: 1,
        out: "✘ This Worker does not exist on your account. [code: 10007]",
      },
    )
    expect(r.status).toBe(0)
    expect(r.calls[0]).toMatch(
      /^exec wrangler secret list --name acme-web-stage --config wrangler.jsonc --format json$/,
    )
    expect(r.calls[1]).toMatch(
      /^exec wrangler secret bulk --name acme-web-stage --config wrangler.jsonc$/,
    )
    expect(Object.keys(r.bulk!).sort()).toEqual([
      "AUTH_GITHUB_ID",
      "AUTH_GITHUB_SECRET",
      "AUTH_SECRET",
    ])
    expect(r.bulk!.AUTH_SECRET).toMatch(/^[A-Za-z0-9_-]{43}$/)
    // Never on a command line, never in the log.
    expect(r.calls.join(" ")).not.toContain(r.bulk!.AUTH_SECRET)
    expect(r.out).not.toContain(r.bulk!.AUTH_SECRET)
  })

  it("keeps the AUTH_SECRET a Worker already carries", () => {
    const r = run(
      deploy,
      { ...token, AUTH_GITHUB_ID: "id", AUTH_GITHUB_SECRET: "s" },
      listing(["AUTH_SECRET"]),
    )
    expect(r.status).toBe(0)
    expect(Object.keys(r.bulk!).sort()).toEqual([
      "AUTH_GITHUB_ID",
      "AUTH_GITHUB_SECRET",
    ])
    expect(r.out).toMatch(/AUTH_SECRET already on acme-web-stage, kept/)
  })

  it("pushes nothing when the Worker has its key and no provider is connected", () => {
    const r = run(deploy, token, listing(["AUTH_SECRET"]))
    expect(r.status).toBe(0)
    expect(r.calls).toHaveLength(1)
    expect(r.bulk).toBeNull()
  })

  it("refuses to mint a replacement when the Worker's secrets cannot be read", () => {
    const r = run(deploy, token, {
      status: 1,
      out: "✘ Authentication error [code: 10000]",
    })
    expect(r.status).not.toBe(0)
    expect(r.bulk).toBeNull()
    expect(r.out).toMatch(/refusing to mint a replacement/)
  })

  it("uses a stored AUTH_SECRET as it is, without asking the Worker", () => {
    const r = run(
      deploy,
      { ...token, AUTH_SECRET: "stored-by-the-owner" },
      listing([]),
    )
    expect(r.status).toBe(0)
    expect(r.calls.some((c) => c.includes("secret list"))).toBe(false)
    expect(r.bulk).toEqual({ AUTH_SECRET: "stored-by-the-owner" })
  })

  it("writes .dev.vars, keeping a generated key it already holds and the owner's lines", () => {
    const dir = mkdtempSync(join(tmpdir(), "dev-vars-"))
    const file = join(dir, ".dev.vars")
    const args = [
      "--dev-vars",
      file,
      "--generate",
      "AUTH_SECRET",
      "--secret",
      "AUTH_GITHUB_ID",
    ]
    expect(run(args, {}, listing([])).status).toBe(0)
    const first = readFileSync(file, "utf8")
    expect(first).toMatch(/^AUTH_SECRET="[A-Za-z0-9_-]{43}"$/m)
    writeFileSync(file, `${first}MY_OWN="kept"\n`)
    expect(run(args, { AUTH_GITHUB_ID: "id" }, listing([])).status).toBe(0)
    const second = readFileSync(file, "utf8")
    expect(second).toContain(first.trim())
    expect(second).toContain('MY_OWN="kept"')
    expect(second).toContain('AUTH_GITHUB_ID="id"')
  })
})
