<script lang="ts">
  import { SignIn } from "@auth/sveltekit/components"
  import { pageTitle } from "../../site"

  export let data
</script>

<svelte:head>
  <title>{pageTitle("Sign in")}</title>
</svelte:head>

<main>
  <h1>Sign in</h1>
  {#if data.connected.length > 0}
    <p>Choose how to sign in:</p>
    <ul class="providers" data-providers={data.connected.length}>
      {#each data.connected as provider}
        <li>
          <SignIn provider={provider.id} signInPage="signin">
            <div slot="submitButton" class="buttonPrimary">
              Sign in with {provider.name}
            </div>
          </SignIn>
        </li>
      {/each}
    </ul>
  {:else}
    <p role="status" data-providers="0">
      No sign-in provider is connected to this site yet.
    </p>
    <p>
      Connect one by storing its keys as the site's secrets, then redeploy:
      GitHub needs <code>AUTH_GITHUB_ID</code> and
      <code>AUTH_GITHUB_SECRET</code> from a GitHub OAuth app whose callback URL
      is this site's <code>/auth/callback/github</code>. The site's README,
      "Sign-in providers", lists the keys every provider takes.
    </p>
    <details>
      <summary>Every provider this site can offer</summary>
      <ul>
        {#each data.available as provider}
          <li>
            {provider.name}: {#each provider.keys as key, i}<code>{key}</code
              >{i < provider.keys.length - 1 ? ", " : ""}{/each}
          </li>
        {/each}
      </ul>
    </details>
  {/if}
</main>

<style>
  main {
    flex: 1;
  }
  .providers {
    list-style: none;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }
  .buttonPrimary {
    display: inline-block;
    font-weight: 500;
    border-radius: 0.3rem;
    cursor: pointer;
    font-size: 1rem;
    line-height: 1.4rem;
    background-color: #346df1;
    color: #fff;
    padding: 0.7rem 1.4rem;
  }
</style>
