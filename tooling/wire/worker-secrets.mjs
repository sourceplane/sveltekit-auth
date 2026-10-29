#!/usr/bin/env node
// Worker SECRETS from the job's environment (zero-dependency).
//
// Some values must reach the Worker at request time and never a bundle: the
// key Auth.js encrypts its session cookie with (AUTH_SECRET) and the sign-in
// providers' client ids and secrets. The deploy lane has the providers' keys
// in its environment (Orun secrets the component's `optionalSecretEnv`
// resolves), and this hands the named variables that are set to
// `wrangler secret bulk` as JSON over stdin, so no value is ever on a command
// line or in a log.
//
//   node worker-secrets.mjs --worker <worker-name> [--config wrangler.jsonc] \
//     --secret AUTH_GITHUB_ID [--secret …] [--generate AUTH_SECRET …]
//
//   --generate <NAME>   a secret the Worker must have and nobody types: when
//                       the job's environment does not set it and the Worker
//                       does not already carry it (`wrangler secret list`), a
//                       fresh 32-byte random value is pushed with the others.
//                       So the FIRST deploy of an environment mints it, every
//                       later deploy keeps it, and a value stored as an Orun
//                       secret (the same name in the environment) wins. A
//                       Worker that does not exist yet carries nothing; any
//                       other failure to read its secrets stops the deploy
//                       rather than replace a key every session depends on.
//   --dev-vars <file>   write the same secrets as KEY=value lines instead
//                       (wrangler dev and `vite dev` read .env as the
//                       Worker's secrets), keeping the file's other lines and
//                       any generated value it already holds
//
// The --secret values are OPTIONAL, like the Orun secrets they come from: a
// variable that is not set is skipped, named, and the site reads its absence
// at request time (src/server/providers.ts offers only the providers whose
// keys are set). Only a job that can deploy holds a Cloudflare credential
// (the composition's deploy profile binds CLOUDFLARE_API_TOKEN; its verify
// profiles bind nothing), so without one this says so and exits 0: a verify
// lane builds exactly what the deploy lane does and pushes nothing.
import * as fs from "node:fs";
import { randomBytes } from "node:crypto";
import { spawnSync } from "node:child_process";

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}
function args(name) {
  const out = [];
  process.argv.forEach((a, i) => {
    if (a === `--${name}` && process.argv[i + 1] !== undefined) out.push(process.argv[i + 1]);
  });
  return out;
}

const worker = arg("worker");
const config = arg("config");
const devVars = arg("dev-vars");
const names = args("secret");
const generated = args("generate");
if (names.length + generated.length === 0 || (!worker && !devVars)) {
  console.error(
    "usage: worker-secrets.mjs --secret NAME [--secret …] [--generate NAME …] (--worker <name> [--config <file>] | --dev-vars <file>)",
  );
  process.exit(2);
}
for (const name of [...names, ...generated]) {
  if (!/^[A-Z][A-Z0-9_]*$/.test(name)) {
    console.error(`worker-secrets: ${name} is not an environment variable name`);
    process.exit(2);
  }
}

const fresh = () => randomBytes(32).toString("base64url");
const isSet = (v) => typeof v === "string" && v.length > 0;

const secrets = {};
const unset = [];
for (const name of [...new Set([...names, ...generated])]) {
  const value = process.env[name];
  if (isSet(value)) secrets[name] = value;
  else if (!generated.includes(name)) unset.push(name);
}
if (unset.length > 0) console.log(`worker-secrets: not set, skipped: ${unset.join(", ")}`);
// Generated names the environment does not set; decided below, per target.
const toGenerate = generated.filter((n) => !(n in secrets));

if (devVars) {
  // Keep what the file already says: an owner's own lines, and a generated
  // value it holds (a new one would sign every local session out).
  const kept = new Map();
  if (fs.existsSync(devVars)) {
    for (const line of fs.readFileSync(devVars, "utf8").split("\n")) {
      const m = /^([A-Z][A-Z0-9_]*)=(.*)$/.exec(line);
      if (m) kept.set(m[1], m[2]);
    }
  }
  for (const name of toGenerate) {
    const old = kept.get(name);
    if (old && old !== '""') continue;
    secrets[name] = fresh();
  }
  for (const [k, v] of Object.entries(secrets)) kept.set(k, JSON.stringify(v));
  // KEY=value, one per line, double-quoted (dotenv's syntax, which wrangler
  // reads): a JSON string is a valid dotenv double-quoted value.
  const body = [...kept.entries()].map(([k, v]) => `${k}=${v}`).join("\n");
  fs.writeFileSync(devVars, `${body}\n`, { mode: 0o600 });
  const wrote = Object.keys(secrets);
  console.log(`worker-secrets: wrote ${wrote.length ? wrote.join(", ") : "nothing new"} to ${devVars}`);
  process.exit(0);
}

const scope = ["--name", worker, ...(config ? ["--config", config] : [])];

if (!process.env.CLOUDFLARE_API_TOKEN) {
  const all = [...Object.keys(secrets), ...toGenerate];
  console.log(`worker-secrets: no Cloudflare credential in this job (a verify lane) — ${all.join(", ")} reach ${worker} from the deploy lane`);
  process.exit(0);
}

if (toGenerate.length > 0) {
  // What the Worker already carries. A Worker that has never been deployed
  // has no secrets to list (Cloudflare answers 10007, wrangler says it does
  // not exist); anything else is a question this cannot answer, and minting a
  // new key on a guess would sign out every session the old one sealed.
  const listed = spawnSync("pnpm", ["exec", "wrangler", "secret", "list", ...scope, "--format", "json"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  let present = [];
  if (listed.status === 0) {
    try {
      present = JSON.parse(listed.stdout.slice(listed.stdout.indexOf("["))).map((s) => s.name);
    } catch {
      console.error(`worker-secrets: could not read the secrets ${worker} carries: ${listed.stdout.trim().slice(0, 200)}`);
      process.exit(1);
    }
  } else {
    const said = `${listed.stdout}\n${listed.stderr}`;
    if (!/10007|does not exist|not found/i.test(said)) {
      console.error(`worker-secrets: could not list the secrets ${worker} carries — refusing to mint a replacement:`);
      console.error(said.trim().split("\n").slice(-5).join("\n"));
      process.exit(listed.status ?? 1);
    }
    console.log(`worker-secrets: ${worker} does not exist yet; it carries no secrets`);
  }
  for (const name of toGenerate) {
    if (present.includes(name)) console.log(`worker-secrets: ${name} already on ${worker}, kept`);
    else {
      secrets[name] = fresh();
      console.log(`worker-secrets: ${name} generated for ${worker}`);
    }
  }
}

const set = Object.keys(secrets);
if (set.length === 0) {
  console.log("worker-secrets: nothing to set");
  process.exit(0);
}
const list = set.join(", ");
const result = spawnSync("pnpm", ["exec", "wrangler", "secret", "bulk", ...scope], {
  input: JSON.stringify(secrets),
  stdio: ["pipe", "inherit", "inherit"],
});
if (result.status !== 0) {
  console.error(`worker-secrets: wrangler secret bulk failed for ${worker}`);
  process.exit(result.status ?? 1);
}
console.log(`worker-secrets: ${list} set on ${worker}`);
