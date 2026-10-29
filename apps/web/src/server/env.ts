import { env } from "$env/dynamic/private"
import { workerVars, type Vars } from "./vars"

/** The variables and secrets this request's Worker carries. */
export function serverEnv(event: { platform?: App.Platform }): Vars {
  return workerVars(env, event.platform?.env)
}
