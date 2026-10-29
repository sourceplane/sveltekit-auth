# sveltekit-auth — open risks

What is not yet proven or not yet decided. The full write-up of every risk,
including the accepted ones, is
`specs/epics/sveltekit-auth/risks-and-open-questions.md`; this page lists
only what is still live, so it should be short.

| ID | Risk | State | What closes it |
|---|---|---|---|
| SU-A | No live bootstrap yet: the brokered token's reach over Worker secrets, `secret bulk` creating the Worker on a first deploy, a real `wrangler deploy` and the probes are unproven | OPEN | One bootstrap from `baseline-v1` against a workspace, signing in with a GitHub OAuth app on stage |

Accepted, and worth knowing before you change them: SU-B (a failed secret
list stops the deploy rather than mint a replacement), SU-C (`@auth/sveltekit`
pinned exactly), SU-D (JWT sessions cannot be revoked), SU-E (nine providers
have secret refs), SU-F (upstream's dicebear avatar), SU-G (`nodejs_compat`).
