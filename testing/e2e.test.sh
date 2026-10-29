#!/usr/bin/env bash
# TIER 2 — the site a bootstrap produces builds, deploys (dry) and serves.
#
# placement.test.sh proves the tree a bootstrap ends with is the right tree.
# This proves it WORKS, by doing to it what its own pipelines will:
#
#   1. at the finished site, the landing's own checks — install with the
#      lockfile the site ships, render fixtures, typecheck, lint, test,
#      build. The bootstrap's own landings are checked in the box with
#      `orun validate` and `orun plan` alone (`checks: local`; their PR's CI
#      on an `orun/BASE-…` branch is `plan` alone, and the convergence on
#      main builds, deploys and smoke-tests the site), and a later pull
#      request of the site runs ci.yml's verify lanes, which build and
#      dry-deploy it but do not lint or run the tests — so THIS is where a
#      site those steps refuse is caught: before the tag, not after a build
#      has merged it;
#   2. the stage lane's own steps, rendered by `orun plan` in the site: on a
#      pull request (the verify profile) `build-app` — the component's
#      buildCommand, the same step the deploy profile runs; `vite build`, where
#      @sveltejs/adapter-cloudflare writes `_worker.js` and the static output
#      to where wrangler.jsonc's `main` and `assets.directory` point —
#      `verify-build-output` (the component's `workerEntrypoint` and
#      `assetsDir`) and `deploy-dry-run` (`wrangler deploy --dry-run --config
#      wrangler.jsonc --name <reponame>-web-stage`, which bundles the adapter's
#      Worker). They run IN THE TREE THE RUNNER STAGES for the job
#      (testing/lib/stage-job.py), with the dependency layout the pinned
#      composition produces: if its install step is `scope: lane`, the
#      top-level node_modules is a symlink to the source checkout's; if not,
#      the job's own install step runs inside the staged tree. (Run in a plain
#      checkout, the portfolio baseline's equivalent tier was green while its
#      first live bootstrap's lanes died in the lane layout.);
#   3. serve the built Worker with `wrangler dev` FROM THAT STAGED TREE and run
#      the component's OWN `smokeCommand` against it, verbatim — the check the
#      real deploy ends with — three times over, as the site lives:
#      a. with NO `AUTH_SECRET` (a Worker whose deploy lane never set one):
#         Auth.js cannot read a session without it, and the smoke must refuse
#         the site rather than call it live;
#      b. with the secret `pnpm secret:dev` mints into `.env` (0600, kept on
#         a second run) and no sign-in provider: the smoke passes, and every
#         route the site promises answers — the home page's heading and title
#         carry the site's name (escaped, not broken, by an `&` and an `'`),
#         `/auth/session` is `null`, `/signin` says no provider is connected
#         and what to connect, a sign-in attempt goes back there, `/protected`
#         denies, the static files and the hashed `_app` chunks are served,
#         and an unknown path is SvelteKit's 404 page;
#      c. with GitHub's two keys set: `/signin` offers GitHub, and its form
#         post is GitHub's authorize URL with this site's own callback; a
#         session cookie minted with the Worker's AUTH_SECRET (Auth.js's own
#         JWT encoding — what a finished OAuth callback sets) opens
#         `/protected` and names the user, one minted with any other secret is
#         no session, and signing out clears it.
#      No value planted in the build's environment reaches the built Worker.
#
# What it cannot do is the platform's half: create the repository, mint the
# brokered Cloudflare token, deploy for real and probe workers.dev. That is a
# bootstrap against a workspace (BOOTSTRAP.md); everything short of it is here.
#
# Needs: orun, node, pnpm, python3 (+PyYAML), git, curl, and the network for
# `pnpm install` (or a warm store). A few minutes: two installs and builds
# (the landing's checks over the site, and the stage lane's own in its staged
# tree).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$here/lib/bootstrap.sh"

for bin in orun node pnpm python3 git curl; do
  command -v "$bin" >/dev/null || { echo "e2e.test.sh needs $bin on PATH" >&2; exit 1; }
done

scratch="$(mktemp -d)"
dev_pid=""
# wrangler dev runs under pnpm, node and two workerd processes; a TERM to the
# first does not reach the rest, and waiting on it then never returns. So it is
# started as its own process group (setsid) and the whole group is stopped.
stop_dev() {
  if [ -n "$dev_pid" ]; then
    kill -TERM -- "-$dev_pid" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$dev_pid" 2>/dev/null || break; sleep 0.5; done
    kill -KILL -- "-$dev_pid" 2>/dev/null || true
    dev_pid=""
  fi
}
cleanup() {
  stop_dev
  rm -rf "$scratch"
}
trap cleanup EXIT
values="$here/fixtures/acme.json"
repo="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['reponame'])" "$values")"
export CI=1 WRANGLER_SEND_METRICS=false TURBO_TELEMETRY_DISABLED=1

# The landing's own checks, step for step, run here at once on the whole
# tree. A pull request in the site builds and dry-deploys it through ci.yml's
# lanes; the lint and the tests run here, and by hand before a push.
LANDING_CHECKS=(
  "pnpm install --frozen-lockfile"
  "pnpm run wire:fixture"
  "pnpm typecheck"
  "pnpm lint"
  "pnpm test"
  "pnpm build"
)
checks() { # DIR LOG
  local dir="$1" log="$2" cmd
  for cmd in "${LANDING_CHECKS[@]}"; do
    echo "   \$ $cmd" | tee -a "$log"
    if ! (cd "$dir" && bash -c "$cmd") >> "$log" 2>&1; then
      echo "FAIL: \`$cmd\` failed in $dir" >&2; tail -40 "$log" >&2; return 1
    fi
  done
}

echo "── the offline bootstrap (testing/lib/bootstrap.sh)"
tree="$scratch/$repo"
bootstrap_offline "$root" "$tree" "$values" "$scratch/logs" > "$scratch/bootstrap.log" 2>&1 || {
  echo "FAIL: the offline bootstrap stopped" >&2; tail -40 "$scratch/bootstrap.log" >&2; exit 1; }
echo "   2 phases placed and landed"

# ── 1. the finished site ───────────────────────────────────────────────────
echo "── the finished site: install, the fixture render, typecheck, lint, test, build"
checks "$tree" "$scratch/checks-site.log"

# ── 2. the deploy lane's steps, for stage ──────────────────────────────────
echo "── the stage lane: build-app, verify-build-output, deploy-dry-run"
# The 01-product landing over the repository's empty first commit: every file
# of the site changed, as on its pull request.
s00="$(git -C "$tree" rev-parse HEAD~2)"; s01="$(git -C "$tree" rev-parse HEAD~1)"
(cd "$tree" && orun plan --intent intent.yaml --trigger github-pull-request --changed \
   --base "$s00" --head "$s01" --env stage --output "$scratch/plan.json") > "$scratch/plan.log" 2>&1 \
  || { echo "FAIL: orun plan" >&2; tail -15 "$scratch/plan.log" >&2; exit 1; }
python3 - "$scratch/plan.json" "$scratch/steps" <<'PY'
import json, pathlib, sys
plan = json.load(open(sys.argv[1]))
out = pathlib.Path(sys.argv[2]); out.mkdir()
job = next(j for j in plan["jobs"] if j["component"] == "web" and j["environment"] == "stage")
for s in job["steps"]:
    if s["id"] in ("build-app", "verify-build-output", "deploy-dry-run"):
        (out / f"{s['id']}.sh").write_text(s.get("run") or "")
    if s["id"] == "install-workspace-dependencies":
        (out / "install.sh").write_text(s.get("run") or "")
        (out / "install.wd").write_text(s.get("working-directory") or ".")
        (out / "install.scope").write_text(s.get("scope") or "job")
(out / "path").write_text(job.get("path") or "apps/web")
for k, v in (job.get("env") or {}).items():
    (out / "env").open("a").write(f"export {k}={json.dumps(v)}\n")
PY
# The job's private tree, staged as orun stages it. The source checkout
# carries no build output (a CI checkout has none, so the plain-tree build's is
# removed rather than copied in), and its dependencies are what the pinned
# composition says: a lane-scoped install ran once in the source tree (step 1
# ran the same command) and is linked in, or the job installs its own.
rm -rf "$tree/apps/web/.svelte-kit" "$tree/apps/web/.wrangler"
work="$tree/.orun/runs/e2e/web.stage.verify-deploy/work"
[ -f "$scratch/steps/install.sh" ] || { echo "FAIL: the stage lane has no install step" >&2; exit 1; }
if [ "$(cat "$scratch/steps/install.scope")" = lane ]; then
  python3 "$here/lib/stage-job.py" "$tree" "$work" --shared-deps
  [ -L "$work/node_modules" ] || { echo "FAIL: the staged tree's node_modules is not the lane's symlink" >&2; exit 1; }
  echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: lane — node_modules → the source tree's"
else
  python3 "$here/lib/stage-job.py" "$tree" "$work"
  echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: job — installing inside it"
  echo "   ▸ install-workspace-dependencies"
  (cd "$work/$(cat "$scratch/steps/path")/$(cat "$scratch/steps/install.wd")" && bash -e "$scratch/steps/install.sh") \
    > "$scratch/install.log" 2>&1 || { echo "FAIL: the lane's install step" >&2; tail -30 "$scratch/install.log" >&2; exit 1; }
  [ -d "$work/node_modules" ] && [ ! -L "$work/node_modules" ] \
    || { echo "FAIL: the job's install did not land inside its own tree" >&2; exit 1; }
fi
# Values planted where a deploy lane's optional secrets would be: the build
# must never see them (buildCommand unsets each before `vite build`), and with
# no Cloudflare credential (a verify lane binds none) worker-secrets.mjs
# names them and pushes nothing.
planted_auth="e2e-planted-auth-secret-$RANDOM$RANDOM"
planted_gh="e2e-planted-github-secret-$RANDOM$RANDOM"
for step in build-app verify-build-output deploy-dry-run; do
  [ -f "$scratch/steps/$step.sh" ] || { echo "FAIL: the stage verify lane has no $step step" >&2; exit 1; }
  echo "   ▸ $step"
  # The runner's per-job environment: the job's env (intent environment
  # `env:`) and ORUN_ENVIRONMENT; the step runs in the component's directory.
  if ! (cd "$work/$(cat "$scratch/steps/path")" && \
        { [ -f "$scratch/steps/env" ] && source "$scratch/steps/env"; true; } && \
        unset CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID && \
        export ORUN_ENVIRONMENT=stage AUTH_SECRET="$planted_auth" \
               AUTH_GITHUB_ID=e2e-planted-github-id AUTH_GITHUB_SECRET="$planted_gh" && \
        bash -e "$scratch/steps/$step.sh") > "$scratch/$step.log" 2>&1; then
    echo "FAIL: the deploy lane's $step step" >&2; tail -40 "$scratch/$step.log" >&2; exit 1
  fi
done
grep -qF "worker-secrets: no Cloudflare credential in this job (a verify lane) — AUTH_GITHUB_ID, AUTH_GITHUB_SECRET, AUTH_SECRET reach $repo-web-stage from the deploy lane" \
  "$scratch/build-app.log" || { echo "FAIL: build-app did not hand the stage Worker its secrets as a verify lane does" >&2; tail -10 "$scratch/build-app.log" >&2; exit 1; }
if grep -rqsF -e "$planted_auth" -e "$planted_gh" "$work/apps/web/.svelte-kit" "$scratch/build-app.log" "$scratch/deploy-dry-run.log"; then
  echo "FAIL: a secret in the build's environment reached the built Worker or a log" >&2; exit 1
fi
for f in .env .dev.vars; do
  [ ! -e "$work/apps/web/$f" ] || { echo "FAIL: the stage lane wrote a $f" >&2; exit 1; }
done
echo "     the verify lane names the stage Worker's secrets and pushes none; none reaches the bundle"

# ── 3. serve it, and smoke it as the deploy does ───────────────────────────
port=$(python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()")
url="http://127.0.0.1:$port"
web="$work/apps/web"
smoke="$(python3 -c "import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))['spec']['parameters']['smokeCommand'])" "$tree/apps/web/component.yaml")"
start_dev() { # LOG
  (cd "$web" && exec setsid pnpm exec wrangler dev --config wrangler.jsonc --ip 127.0.0.1 --port "$port" \
     --name "$repo-web-stage" --show-interactive-dev-session=false) > "$1" 2>&1 < /dev/null &
  dev_pid=$!
  for _ in $(seq 1 90); do
    curl -s -o /dev/null "$url/robots.txt" && return 0
    kill -0 "$dev_pid" 2>/dev/null || { echo "FAIL: wrangler dev exited" >&2; tail -30 "$1" >&2; exit 1; }
    sleep 1
  done
  echo "FAIL: wrangler dev never answered" >&2; tail -30 "$1" >&2; exit 1
}
routes() { # MODE: bare (a secret, no provider) | github (GitHub's keys set)
  python3 - "$url" "$values" "$1" "$web" <<'PY'
import html, json, os, re, subprocess, sys, urllib.error, urllib.parse, urllib.request
base, values, mode, web = sys.argv[1], json.load(open(sys.argv[2])), sys.argv[3], sys.argv[4]
name = values["productname"]
problems = []
def bad(m): problems.append(m)
class Stay(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k): return None
opener = urllib.request.build_opener(Stay)
def get(path, data=None, headers=None):
    req = urllib.request.Request(base + path, data=data, headers=headers or {})
    try:
        with opener.open(req, timeout=60) as r:
            return r.status, r.headers, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers, e.read()
def text(fragment):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", fragment))).strip()
def title(page):
    m = re.search(r"<title>(.*?)</title>", page, re.S)
    return m and html.unescape(m.group(1))
def post(path, fields, extra=None):
    # As a browser posts a form: it asks for HTML, so an action's redirect is
    # a redirect (asked for anything, SvelteKit answers an ActionResult).
    headers = {"content-type": "application/x-www-form-urlencoded", "origin": base, "accept": "text/html", **(extra or {})}
    return get(path, data=urllib.parse.urlencode(fields).encode(), headers=headers)
def jwt(secret):
    # Auth.js's own encoding, from the @auth/core the site resolves: the
    # cookie a finished OAuth callback sets, minus the provider round trip.
    js = ("import{realpathSync}from'node:fs';import{join}from'node:path';import{pathToFileURL}from'node:url';"
          "const c=join(realpathSync('node_modules/@auth/sveltekit'),'..','core');"
          "const{encode}=await import(pathToFileURL(join(c,'jwt.js')).href);"
          "process.stdout.write(await encode({token:{name:process.env.N,email:process.env.E,sub:'e2e-1'},"
          "secret:process.env.S,salt:'authjs.session-token',maxAge:3600}))")
    env = {**os.environ, "S": secret, "N": name, "E": "sam@acme.test"}
    return subprocess.run(["node", "--input-type=module", "-e", js], cwd=web, env=env,
                          capture_output=True, text=True, check=True).stdout
def dev_var(key):
    for line in open(os.path.join(web, ".env")):
        k, _, v = line.rstrip("\n").partition("=")
        if k == key:
            return json.loads(v) if v.startswith('"') else v
    return None

# / — rendered by the Worker, the site's name on it.
status, _, body = get("/")
page = body.decode()
if status != 200:
    bad(f"/ answered {status}")
h1 = re.search(r"<h1[^>]*>(.*?)</h1>", page, re.S)
if not h1 or text(h1.group(1)) != name:
    bad(f"the home page's heading reads {h1 and text(h1.group(1))!r}, not {name!r}")
if title(page) != name:
    bad(f"the home page's <title> is {title(page)!r}, not {name!r}")
if "SvelteKit Auth Example" in page or "sveltekit-auth" in page.replace("sveltekit-auth-example", ""):
    bad("the home page still carries the baseline's name")
for nav in ('href="/"', 'href="/protected"'):
    if nav not in page:
        bad(f"the home page's nav has no {nav}")

if mode == "bare":
    if "You are not signed in" not in page:
        bad("the header does not say the visitor is not signed in")
    # The hashed client chunks the home page boots from, and the static files.
    chunks = sorted(set(re.findall(r"(_app/immutable/[^\"'\s)]+\.js)", page)))
    if not chunks:
        bad("the home page references no _app/immutable chunk")
    for chunk in chunks[:3]:
        s, h, _ = get("/" + chunk)
        if s != 200 or "javascript" not in (h.get("content-type") or ""):
            bad(f"/{chunk} answered {s} {h.get('content-type')}")
    for path, ctype in (("/favicon.ico", "image/"), ("/robots.txt", "text/plain")):
        s, h, _ = get(path)
        if s != 200 or not (h.get("content-type") or "").startswith(ctype):
            bad(f"{path} answered {s} {h.get('content-type')}, want 200 {ctype}")

    # Auth.js's own routes, answered by the Worker.
    s, _, body = get("/auth/session")
    if s != 200 or body.strip() != b"null":
        bad(f"/auth/session answered {s} {body[:80]!r}, not 200 null")
    s, _, body = get("/auth/providers")
    if s != 200 or json.loads(body or b"null") != {}:
        bad(f"/auth/providers answered {s} {body[:80]!r}, not 200 {{}}")

    # /signin, with nothing connected: says so, and what to connect.
    s, _, body = get("/signin")
    signin = body.decode()
    if s != 200 or title(signin) != f"Sign in | {name}":
        bad(f"/signin answered {s}, <title> {title(signin)!r}")
    if 'data-providers="0"' not in signin or "No sign-in provider is connected to this site yet." not in signin:
        bad("/signin does not say no provider is connected")
    if "AUTH_GITHUB_ID" not in signin or "AUTH_GITHUB_SECRET" not in signin:
        bad("/signin does not say which keys connect GitHub")
    # The header's own Sign in button posts an empty providerId (Auth.js's
    # default); a provider's button would name one.
    if re.search(r'name="providerId" value="[^"]+"', signin):
        bad("/signin offers a provider's sign-in button with no provider connected")
    s, h, _ = post("/signin", {"providerId": "github"})
    if s != 303 or h.get("location") != "/signin":
        bad(f"a sign-in with nothing connected answered {s} {h.get('location')}, not 303 /signin")

    # /protected, signed out.
    s, _, body = get("/protected")
    prot = body.decode()
    if s != 200 or "<h1>Access Denied</h1>" not in prot or title(prot) != f"Protected | {name}":
        bad(f"/protected, signed out, answered {s} without 'Access Denied'")

    # An unknown path is SvelteKit's own 404, rendered by the Worker.
    s, _, body = get("/no-such-page")
    nf = body.decode()
    if s != 404 or "<h1>404</h1>" not in nf:
        bad(f"/no-such-page answered {s} without SvelteKit's 404 page")
    done = "/, the _app chunks, the static files, /auth/session, /auth/providers, /signin and its post, /protected, a 404"

else:
    s, _, body = get("/signin")
    signin = body.decode()
    if 'data-providers="1"' not in signin or "Sign in with GitHub" not in signin:
        bad("/signin, with GitHub's keys set, does not offer GitHub")
    if "No sign-in provider is connected" in signin:
        bad("/signin still says nothing is connected")
    if 'name="providerId" value="github"' not in signin:
        bad("/signin's GitHub button does not post providerId=github")
    s, _, body = get("/auth/providers")
    provs = json.loads(body or b"{}")
    if list(provs) != ["github"] or provs["github"].get("callbackUrl") != f"{base}/auth/callback/github":
        bad(f"/auth/providers answered {provs}, not GitHub with this site's callback")
    s, h, _ = post("/signin", {"providerId": "github"})
    loc = urllib.parse.urlsplit(h.get("location") or "")
    q = urllib.parse.parse_qs(loc.query)
    if s != 302 or f"{loc.scheme}://{loc.netloc}{loc.path}" != "https://github.com/login/oauth/authorize":
        bad(f"a GitHub sign-in answered {s} {h.get('location')!r}, not GitHub's authorize URL")
    if q.get("client_id") != [dev_var("AUTH_GITHUB_ID")] or q.get("redirect_uri") != [f"{base}/auth/callback/github"]:
        bad(f"GitHub's authorize URL carries client_id {q.get('client_id')} and redirect_uri {q.get('redirect_uri')}")
    if "code_challenge" not in q:
        bad("the GitHub sign-in carries no PKCE challenge")
    if dev_var("AUTH_GITHUB_SECRET") in (h.get("location") or ""):
        bad("the GitHub client secret is in the authorize URL")

    # A session: Auth.js's JWT, sealed with the Worker's own AUTH_SECRET.
    jar = {"cookie": f"authjs.session-token={jwt(dev_var('AUTH_SECRET'))}"}
    s, _, body = get("/auth/session", headers=jar)
    sess = json.loads(body or b"null") or {}
    if s != 200 or (sess.get("user") or {}).get("email") != "sam@acme.test":
        bad(f"/auth/session with the site's own session answered {s} {body[:100]!r}")
    s, _, body = get("/protected", headers=jar)
    prot = body.decode()
    if "<h1>Protected page</h1>" not in prot or "sam@acme.test" not in prot or "Session expiry:" not in prot:
        bad("/protected, signed in, does not show the protected page and who is signed in")
    if "You are not signed in" in prot:
        bad("the header, signed in, still says the visitor is not signed in")
    # One sealed with any other secret is no session at all.
    other = {"cookie": f"authjs.session-token={jwt('not-this-sites-secret-' + 'x' * 32)}"}
    s, _, body = get("/auth/session", headers=other)
    if body.strip() != b"null":
        bad(f"a session sealed with another secret was accepted: {body[:100]!r}")
    s, _, body = get("/protected", headers=other)
    if "<h1>Access Denied</h1>" not in body.decode():
        bad("/protected opened for a session sealed with another secret")
    # Signing out clears it.
    s, h, _ = post("/signout", {}, jar)
    cleared = [c for c in (h.get_all("set-cookie") or []) if c.startswith("authjs.session-token=")]
    if s not in (302, 303) or not cleared or "max-age=0" not in cleared[0].lower().replace(" ", ""):
        bad(f"sign-out answered {s} {cleared}, without clearing the session cookie")
    elif "httponly" not in cleared[0].lower():
        bad("the session cookie is not httpOnly")
    done = "/signin offers GitHub and posts to its authorize URL; a session opens /protected, another secret's does not; sign-out clears it"

if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
print(f"     {done}")
PY
}

echo "── wrangler dev over the built Worker, with no AUTH_SECRET"
start_dev "$scratch/dev-bare.log"
echo "   ▸ the component's own smokeCommand refuses it, DEPLOYED_URL=$url"
if DEPLOYED_URL="$url" bash -c "$smoke" > "$scratch/smoke-nosecret.log" 2>&1; then
  echo "FAIL: the deploy's smoke passed a Worker with no AUTH_SECRET, which cannot read a session" >&2; exit 1
fi
stop_dev

echo "── pnpm secret:dev, then wrangler dev with the secret and no provider"
(cd "$web" && pnpm run secret:dev) > "$scratch/secret-dev.log" 2>&1 \
  || { echo "FAIL: pnpm secret:dev" >&2; tail -10 "$scratch/secret-dev.log" >&2; exit 1; }
[ "$(stat -c %a "$web/.env")" = 600 ] || { echo "FAIL: .env is not 0600" >&2; exit 1; }
first="$(grep '^AUTH_SECRET=' "$web/.env" || true)"
[ "${#first}" -ge 55 ] || { echo "FAIL: .env carries no generated AUTH_SECRET" >&2; exit 1; }
(cd "$web" && pnpm run secret:dev) >> "$scratch/secret-dev.log" 2>&1
[ "$(grep '^AUTH_SECRET=' "$web/.env")" = "$first" ] || { echo "FAIL: a second secret:dev replaced the secret" >&2; exit 1; }
val="${first#AUTH_SECRET=}"; val="${val//\"/}"
if grep -qF -- "$val" "$scratch/secret-dev.log"; then echo "FAIL: secret:dev printed the secret" >&2; exit 1; fi
start_dev "$scratch/dev.log"
echo "   ▸ the component's own smokeCommand, DEPLOYED_URL=$url"
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the site" >&2; exit 1; }
echo "   ▸ every route the site promises, signed out"
routes bare
stop_dev

echo "── wrangler dev with GitHub's keys"
printf 'AUTH_GITHUB_ID="e2e-github-client-id"\nAUTH_GITHUB_SECRET="e2e-github-client-secret-%s"\n' "$RANDOM" >> "$web/.env"
start_dev "$scratch/dev-github.log"
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the site with a provider" >&2; exit 1; }
echo "   ▸ sign-in, a session, sign-out"
routes github
stop_dev

echo "e2e.test.sh: ok"
