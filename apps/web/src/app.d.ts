/// <reference types="@auth/sveltekit" />
/// <reference types="@sveltejs/adapter-cloudflare" />

// See https://svelte.dev/docs/kit/types#app.d.ts
declare global {
  namespace App {
    interface Platform {
      env: Record<string, unknown>
    }
  }
}

export {}
