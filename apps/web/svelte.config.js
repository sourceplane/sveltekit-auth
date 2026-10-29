import adapter from "@sveltejs/adapter-cloudflare"
import { vitePreprocess } from "@sveltejs/vite-plugin-svelte"

/** @type {import('@sveltejs/kit').Config} */
const config = {
  // Consult https://kit.svelte.dev/docs/integrations#preprocessors
  // for more information about preprocessors
  preprocess: vitePreprocess(),

  kit: {
    // adapter-auto (Vercel) becomes adapter-cloudflare: the build emits the
    // Worker (.svelte-kit/cloudflare/_worker.js) with the static output beside
    // it, and the committed wrangler.jsonc deploys both as Workers Static
    // Assets. `platformProxy` points `vite dev` at the same config, so the
    // dev server reads the vars and secrets (.env) the Worker does.
    adapter: adapter({ platformProxy: { configPath: "wrangler.jsonc" } }),
    alias: {
      $components: "src/components",
      $lib: "src/components",
      $routes: "src/routes",
    },
  },
}

export default config
