#!/usr/bin/env bash
# THE REBRAND WRITES EACH VALUE ONCE, AND WHAT IT WROTE STAYS WRITTEN.
#
# Drives the real tooling/rebrand/rebrand.mjs over one-file trees and compares
# the file. Each case is a shape this baseline's identity actually takes in the
# tree — a source link, the site-name seam, the worker name (in the component
# and in wrangler.jsonc), the environment URLs, the placeholder domain, a
# secret ref — and each runs through as many passes as a bootstrap
# makes (every phase re-runs the rebrand over everything already placed), so a
# value written by an early phase must survive every later one unchanged.
#
# The identity is PINNED (fixtures/baseline-identity.sveltekit-auth.json)
# rather than read from .baseline/identity.json: what this tests is the engine,
# and its fixtures spell the identity out literally.
#
# Needs: node, git. No network.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
rebrand="$here/../tooling/rebrand/rebrand.mjs"
identity="$here/fixtures/baseline-identity.sveltekit-auth.json"

fail=0
# check NAME VALUES-JSON FILE CONTENT WANT [PASSES]
check() {
  local name="$1" values="$2" file="$3" content="$4" want="$5" passes="${6:-1}"
  local tmp got out i
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  mkdir -p "$tmp/$(dirname "$file")" "$tmp/.rebrand"
  printf '%s\n' "$content" > "$tmp/$file"
  printf '%s\n' "$values" > "$tmp/.rebrand/values.json"
  for ((i = 1; i <= passes; i++)); do
    git -C "$tmp" add -A
    if ! out="$(cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --values .rebrand/values.json --allow-dirty 2>&1)"; then
      echo "   ✕  $name: rebrand pass $i failed:" >&2
      printf '%s\n' "$out" | sed 's/^/        /' >&2
      fail=1
      rm -rf "$tmp"
      return
    fi
  done
  got="$(cat "$tmp/$file")"
  rm -rf "$tmp"
  if [ "$got" = "$want" ]; then
    echo "   ok  $name"
  else
    echo "   ✕  $name:" >&2
    echo "        got:  $got" >&2
    echo "        want: $want" >&2
    fail=1
  fi
}

acme='{"reponame":"acme-notes","productname":"Acme Notes","productdomain":"acme.dev","githuborg":"acme-inc","subdomain":"acme","orunWorkspace":"ws_79BDXAZQ"}'

echo "── rebrand: the site's own identity"
check "a source link names the product's owner and repository" \
  "$acme" README.md \
  'Source: https://github.com/sourceplane/sveltekit-auth' \
  'Source: https://github.com/acme-inc/acme-notes'
check "the site-name seam takes the product's name" \
  "$acme" apps/web/src/site.ts 'export const SITE_NAME = "SvelteKit Auth Example"' \
  'export const SITE_NAME = "Acme Notes"'
check "…and stays a valid string for a name with an apostrophe and an ampersand" \
  '{"reponame":"sams-notes","productname":"Sam'"'"'s Notes & Links","productdomain":"sam.dev"}' \
  apps/web/src/site.ts 'export const SITE_NAME = "SvelteKit Auth Example"' \
  'export const SITE_NAME = "Sam'"'"'s Notes & Links"'
check "the display name elsewhere is content, and is left alone" \
  "$acme" apps/web/README.md 'Auth.js'"'"'s SvelteKit Auth Example, on Workers.' \
  'Auth.js'"'"'s SvelteKit Auth Example, on Workers.'
check "the worker name is re-prefixed, the environment suffix kept" \
  "$acme" apps/web/component.yaml 'workerName: sveltekit-auth-web' \
  'workerName: acme-notes-web'
check "…and so is the Worker the deploy lane hands its secrets to" \
  "$acme" apps/web/component.yaml 'node ../../tooling/wire/worker-secrets.mjs --worker "sveltekit-auth-web-${ORUN_ENVIRONMENT}" --config wrangler.jsonc' \
  'node ../../tooling/wire/worker-secrets.mjs --worker "acme-notes-web-${ORUN_ENVIRONMENT}" --config wrangler.jsonc'
check "…and so is the name wrangler.jsonc carries" \
  "$acme" apps/web/wrangler.jsonc '  "name": "sveltekit-auth-web",' \
  '  "name": "acme-notes-web",'
check "an environment URL: worker name and subdomain" \
  "$acme" intent.yaml \
  '    url: https://sveltekit-auth-web-stage.your-workers-subdomain.workers.dev' \
  '    url: https://acme-notes-web-stage.acme.workers.dev'
check "the placeholder domain is the product's domain, not a renamed slug" \
  "$acme" intent.yaml '      BASE_DOMAIN: sveltekit-auth.example.com' \
  '      BASE_DOMAIN: acme.dev'
check "no domain given: the reserved placeholder, for an owner to replace later" \
  '{"reponame":"acme-notes","productname":"Acme Notes","githuborg":"acme-inc","subdomain":"acme"}' \
  intent.yaml '      BASE_DOMAIN: sveltekit-auth.example.com' \
  '      BASE_DOMAIN: acme-notes.example.com'
check "an empty domain is no domain" \
  '{"reponame":"acme-notes","productname":"Acme Notes","productdomain":""}' \
  intent.yaml '      BASE_DOMAIN: sveltekit-auth.example.com' \
  '      BASE_DOMAIN: acme-notes.example.com'
check "the repo slug" \
  "$acme" package.json '  "name": "sveltekit-auth",' \
  '  "name": "acme-notes",'
check "a secret ref names the product's workspace and project" \
  "$acme" apps/web/component.yaml 'T: secret://ws_KWQ45Z6M/sveltekit-auth/stage/CLOUDFLARE_API_TOKEN' \
  'T: secret://ws_79BDXAZQ/acme-notes/stage/CLOUDFLARE_API_TOKEN'
check "org-owned identity is not renamed" \
  "$acme" intent.yaml 'apiVersion: sourceplane.io/v1 # mail ops@sourceplane.ai' \
  'apiVersion: sourceplane.io/v1 # mail ops@sourceplane.ai'
check "without githuborg a source link keeps the baseline's owner" \
  '{"reponame":"acme-notes","productname":"Acme Notes","productdomain":"acme.dev"}' \
  README.md 'Source: https://github.com/sourceplane/sveltekit-auth' \
  'Source: https://github.com/sourceplane/acme-notes'

echo "── rebrand: the upstream's own names, which contain the slug, are never rewritten"
check "Auth.js's SvelteKitAuth import (the slug's Pascal form) stays the package's" \
  "$acme" apps/web/src/auth.ts 'import { SvelteKitAuth } from "@auth/sveltekit"' \
  'import { SvelteKitAuth } from "@auth/sveltekit"' 3
check "…and so does the one call" \
  "$acme" apps/web/src/auth.ts 'export const { handle, signIn, signOut } = SvelteKitAuth(async (event) => {' \
  'export const { handle, signIn, signOut } = SvelteKitAuth(async (event) => {' 3
check "the example's repository keeps its name" \
  "$acme" README.md 'Upstream: https://github.com/nextauthjs/sveltekit-auth-example (ISC)' \
  'Upstream: https://github.com/nextauthjs/sveltekit-auth-example (ISC)' 3
check "…beside this repository's own link, which is renamed" \
  "$acme" README.md 'From github.com/nextauthjs/sveltekit-auth-example to https://github.com/sourceplane/sveltekit-auth.' \
  'From github.com/nextauthjs/sveltekit-auth-example to https://github.com/acme-inc/acme-notes.' 3
check "the package it is built on is not a slug" \
  "$acme" apps/web/package.json '    "@auth/sveltekit": "1.11.3"' \
  '    "@auth/sveltekit": "1.11.3"'

echo "── rebrand: a written value is not rewritten, in any later pass"
contains='{"reponame":"sveltekit-auth-2","productname":"SvelteKit Auth Example 2","productdomain":"sveltekit-auth.example.com.au","githuborg":"sourceplane","subdomain":"your-workers-subdomain-2"}'
check "a repo slug containing the baseline's slug survives three passes" \
  "$contains" package.json '  "name": "sveltekit-auth",' \
  '  "name": "sveltekit-auth-2",' 3
check "a worker name built on it survives three passes" \
  "$contains" apps/web/component.yaml 'workerName: sveltekit-auth-web' \
  'workerName: sveltekit-auth-2-web' 3
check "a domain containing the baseline's domain survives three passes" \
  "$contains" intent.yaml 'BASE_DOMAIN: sveltekit-auth.example.com' \
  'BASE_DOMAIN: sveltekit-auth.example.com.au' 3
check "a subdomain containing the placeholder survives three passes" \
  "$contains" apps/web/component.yaml 'workersDevSubdomain: your-workers-subdomain' \
  'workersDevSubdomain: your-workers-subdomain-2' 3
check "a site name containing the baseline's name survives three passes" \
  "$contains" apps/web/src/site.ts 'export const SITE_NAME = "SvelteKit Auth Example"' \
  'export const SITE_NAME = "SvelteKit Auth Example 2"' 3

# --verify runs in every phase. Without the product's values it cannot tell
# the product's own identity from a leftover; with them it can. A real
# leftover must fail it either way.
verify() { # NAME VALUES FILE CONTENT WANT(pass|fail) [--values]
  local name="$1" values="$2" file="$3" content="$4" want="$5" withvalues="${6:-}" tmp got
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  mkdir -p "$tmp/$(dirname "$file")" "$tmp/.rebrand"
  printf '%s\n' "$content" > "$tmp/$file"
  printf '%s\n' "$values" > "$tmp/.rebrand/values.json"
  git -C "$tmp" add -A
  if (cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --verify ${withvalues:+--values .rebrand/values.json} >/dev/null 2>&1); then got=pass; else got=fail; fi
  rm -rf "$tmp"
  if [ "$got" = "$want" ]; then echo "   ok  $name"; else echo "   ✕  $name: --verify ${got}ed, want $want" >&2; fail=1; fi
}
echo "── rebrand --verify: the product's own identity is not residue"
verify "given the values, a slug containing the baseline's passes" \
  "$contains" package.json '"name": "sveltekit-auth-2"' pass --values
verify "without them it cannot know, and fails" \
  "$contains" package.json '"name": "sveltekit-auth-2"' fail
verify "given the values, a real leftover still fails" \
  "$acme" package.json '"name": "sveltekit-auth"' fail --values
verify "a leftover worker name fails" \
  "$acme" apps/web/component.yaml 'workerName: sveltekit-auth-web' fail --values
verify "a leftover code identifier fails (no rule renames it — so nothing may spell it)" \
  "$acme" apps/web/src/lib/x.js 'export class SvelteKitAuth {}' fail --values
verify "the upstream's import and call are not residue" \
  "$acme" apps/web/src/auth.ts 'import { SvelteKitAuth } from "@auth/sveltekit"' pass --values
verify "…nor the example's repository" \
  "$acme" README.md 'https://github.com/nextauthjs/sveltekit-auth-example' pass --values
verify "a clean product passes" \
  "$acme" package.json '"name": "acme-notes"' pass --values

echo "── rebrand: a residue it cannot rename fails the rebrand itself"
tmp="$(mktemp -d)"; git -C "$tmp" init -q; mkdir -p "$tmp/.rebrand" "$tmp/apps/web"
printf '%s\n' "$acme" > "$tmp/.rebrand/values.json"
printf 'const x = "SVELTEKIT_AUTH_TOKEN"\n' > "$tmp/apps/web/x.js"
git -C "$tmp" add -A
if (cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --values .rebrand/values.json --allow-dirty >/dev/null 2>&1); then
  echo "   ✕  an unrenamable env-var prefix passed the rebrand" >&2; fail=1
else
  echo "   ok  an unrenamable env-var prefix fails the rebrand, naming the file"
fi
rm -rf "$tmp"

[ "$fail" -eq 0 ] || exit 1
echo "rebrand.test.sh: ok"
