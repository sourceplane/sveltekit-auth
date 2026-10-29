export type Vars = Record<string, string | undefined>

// The Worker's variables and secrets, by name. Deployed, they are the
// Worker's own bindings (`platform.env`): its secrets, pushed by the deploy
// lane. Locally, `wrangler dev` and the adapter's platform proxy under
// `vite dev` read them from `.dev.vars` or, without one, `.env`, which is
// also what SvelteKit's dynamic env reads under `vite dev`. The bindings win,
// and only their strings count (ASSETS, a binding too, is not a variable).
export function workerVars(
  dynamicEnv: Vars,
  platformEnv?: Record<string, unknown>,
): Vars {
  const vars: Vars = { ...dynamicEnv }
  for (const [name, value] of Object.entries(platformEnv ?? {})) {
    if (typeof value === "string") vars[name] = value
  }
  return vars
}
