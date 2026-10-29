# Epics

Orun-style work programs. Each epic is a folder carrying `epic.yaml` (the
declaration the platform reads: slug, key prefix, milestones with exit
criteria and task keys) beside its doc set. The pull request that adds the
folder is the adoption; the merge creates the epic in the workspace.

| Epic | Cluster | Status | What it is |
|------|---------|--------|------------|
| [`sveltekit-auth/`](./sveltekit-auth/) | **SU** | In progress (SU0) | Auth.js's SvelteKit example — sign-in through any of 26 OAuth providers, each offered once its keys are stored, a protected page, JWT sessions with no database — on Cloudflare Workers + Static Assets, and an Orun baseline that instantiates it in one landing |

As-built ≠ intent: what shipped lives in each epic's `IMPLEMENTATION-STATUS.md`.
