<script lang="ts">
  import { SITE_NAME, pageTitle } from "../site"
</script>

<svelte:head>
  <title>{pageTitle()}</title>
</svelte:head>

<main>
  <h1>{SITE_NAME}</h1>
  <p>
    This is an example site to demonstrate how to use <a
      href="https://kit.svelte.dev/">SvelteKit</a
    >
    with <a href="https://sveltekit.authjs.dev">SvelteKit Auth</a> for authentication.
  </p>
</main>

<style>
  main {
    flex: 1;
  }
</style>
