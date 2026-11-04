// AI eval: replays the scripted chats, surprise events and evening stories
// against Claude and writes a report for people to rate.
//
//   deno run --allow-read --allow-env --allow-net=api.anthropic.com \
//     --allow-write=docs/evals tools/ai-eval/main.ts --label first-run
//
// The key comes from LMS_ANTHROPIC_API_KEY, never ANTHROPIC_API_KEY, so it
// can't mix with any other Claude credentials on the machine.
// --dry-run checks every scenario and builds every prompt with no key and no calls.

import { parseArgs } from "jsr:@std/cli@1/parse-args";
import type { Locale } from "../../server/supabase/functions/_shared/cast.ts";
import {
  type CacheTtl,
  DEFAULT_MODEL,
  type RequestKind,
} from "../../server/supabase/functions/_shared/config.ts";
import { Anthropic } from "../../server/supabase/functions/_shared/deps.ts";
import { markdownReport, ratingsCsv, summarize } from "./report.ts";
import { type CallRecord, CONFIGS, dryRun, runConfig, type Selection } from "./run.ts";
import { CHAT_SCENARIOS, EVENING_INPUTS, EVENT_INPUTS } from "./scenarios.ts";

const args = parseArgs(Deno.args, {
  string: ["configs", "locales", "only", "kinds", "ttl", "label", "out", "model", "concurrency"],
  boolean: ["dry-run", "help"],
  default: {
    configs: "low,medium,low-nothink",
    locales: "en,vi",
    only: "all",
    kinds: "chat,event,evening",
    ttl: "5m",
    label: "run",
    out: "docs/evals",
    concurrency: "4",
  },
});

if (args.help) {
  console.log(`Options:
  --configs low,medium,low-nothink   which settings to compare
  --locales en,vi                    which languages
  --only all | id,id                 chat scenario ids
  --kinds chat,event,evening         which request kinds
  --ttl 5m | 1h                      cache TTL for the shared prompt blocks
  --label NAME                       names the report folder
  --model ID                         override the model (default ${DEFAULT_MODEL})
  --concurrency N                    scenarios in flight at once (default 4)
  --dry-run                          check scenarios and prompts without calling Claude`);
  Deno.exit(0);
}

function list(value: string): string[] {
  return value.split(",").map((v) => v.trim()).filter((v) => v.length > 0);
}

function fail(message: string): never {
  console.error(`ai-eval: ${message}`);
  Deno.exit(2);
}

const locales = list(args.locales) as Locale[];
const kinds = new Set(list(args.kinds) as RequestKind[]);
const only = args.only === "all" ? null : new Set(list(args.only));
const ttl = args.ttl as CacheTtl;
if (ttl !== "5m" && ttl !== "1h") fail(`--ttl must be 5m or 1h, not ${args.ttl}`);
const configs = list(args.configs).map((name) => CONFIGS[name] ?? fail(`unknown config ${name}`));
const concurrency = Number(args.concurrency);
if (!Number.isInteger(concurrency) || concurrency < 1) {
  fail("--concurrency must be a positive integer");
}

const selection: Selection = {
  chats: kinds.has("chat")
    ? CHAT_SCENARIOS.filter((s) => locales.includes(s.locale) && (only === null || only.has(s.id)))
    : [],
  events: kinds.has("event") ? EVENT_INPUTS.filter((e) => locales.includes(e.locale)) : [],
  evenings: kinds.has("evening")
    ? EVENING_INPUTS.filter((e) => locales.includes(e.request.locale))
    : [],
};
if (only !== null) {
  const known = new Set(CHAT_SCENARIOS.map((s) => s.id));
  const unknown = [...only].filter((id) => !known.has(id));
  if (unknown.length > 0) fail(`unknown scenario ids: ${unknown.join(", ")}`);
}

const turns = selection.chats.reduce((n, s) => n + s.turns.length, 0);
const callsPerConfig = turns + selection.events.length + selection.evenings.length;
console.log(
  `Scenarios: ${selection.chats.length} chats (${turns} turns), ${selection.events.length} events, ` +
    `${selection.evenings.length} evening stories. Configs: ${
      configs.map((c) => c.name).join(", ")
    }. ` +
    `Calls: ${callsPerConfig * configs.length}.`,
);

const problems = dryRun(selection, ttl);
if (problems.length > 0) {
  for (const p of problems) console.error(`- ${p}`);
  fail(`${problems.length} scenario problem(s)`);
}
if (args["dry-run"]) {
  console.log("Dry run: every scenario is valid and every prompt builds.");
  Deno.exit(0);
}

const apiKey = Deno.env.get("LMS_ANTHROPIC_API_KEY");
if (!apiKey) fail("set LMS_ANTHROPIC_API_KEY (or use --dry-run)");
const client = new Anthropic({ apiKey, baseURL: "https://api.anthropic.com", maxRetries: 2 });
const model = args.model ?? DEFAULT_MODEL;

const records: CallRecord[] = [];
for (const config of configs) {
  const started = performance.now();
  const results = await runConfig(client, config, selection, { model, cacheTtl: ttl, concurrency });
  records.push(...results);
  const ok = results.filter((r) => r.ok).length;
  console.log(
    `${config.name}: ${ok}/${results.length} valid in ${
      ((performance.now() - started) / 1000).toFixed(0)
    } s`,
  );
}

const now = new Date();
const stamp = now.toISOString().slice(0, 16).replace(/[-:]/g, "").replace("T", "-");
const label = args.label.toLowerCase().replace(/[^a-z0-9-]+/g, "-").replace(/^-+|-+$/g, "") ||
  "run";
const dir = `${args.out}/${stamp}-${label}`;
await Deno.mkdir(dir, { recursive: true });

const meta = { label, date: now.toISOString(), model, cacheTtl: ttl };
await Deno.writeTextFile(`${dir}/report.md`, markdownReport(meta, records));
await Deno.writeTextFile(`${dir}/ratings.csv`, ratingsCsv(records));
await Deno.writeTextFile(
  `${dir}/results.json`,
  JSON.stringify({ meta, summary: summarize(records), records }, null, 2) + "\n",
);
console.log(`REPORT_DIR=${dir}`);

// A run where most calls errored is a setup problem (key, model, request shape), not a result.
const errored = records.filter((r) => r.reason === "error").length;
if (errored > records.length / 2) {
  const sample = records.find((r) => r.reason === "error")?.detail ?? "";
  fail(`${errored} of ${records.length} calls errored, for example: ${sample}`);
}
