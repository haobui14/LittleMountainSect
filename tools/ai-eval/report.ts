// Turns eval records into report.md, results.json and ratings.csv.

import {
  PRICES_PER_MTOK,
  type RequestKind,
} from "../../server/supabase/functions/_shared/config.ts";
import type { TokenBreakdown } from "../../server/supabase/functions/_shared/cost.ts";
import type { CallRecord } from "./run.ts";

/** The GDD's full day of Spirit Energy: 20 messages, 8 evening stories, 3 events. */
export const FULL_USE = { chat: 20, evening: 8, event: 3 } as const;
export const TARGET_USD_PER_PLAYER_DAY = 0.015;

export interface KindStats {
  calls: number;
  ok: number;
  avgTokens: TokenBreakdown;
  avgCost: number;
  /** What the same requests would cost if no cache ever hit. */
  avgCostNoCache: number;
}

export interface ConfigSummary {
  config: string;
  calls: number;
  ok: number;
  refusals: number;
  invalid: number;
  errors: number;
  /** Chat and Elder replies: what Gate 1's reply-time target measures. */
  chatLatencyP50: number;
  chatLatencyP95: number;
  /** Surprise events and evening stories, which the game can prepare ahead. */
  storyLatencyP95: number;
  totalCost: number;
  byKind: Partial<Record<"chat" | "event" | "evening", KindStats>>;
  fullUse: number | null;
  fullUseNoCache: number | null;
  failedChecks: Array<{ scenario: string; turn: number; check: string; note: string }>;
}

function percentile(values: number[], p: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1)];
}

function noCacheCost(t: TokenBreakdown): number {
  const input = t.input + t.cacheRead + t.cacheWrite5m + t.cacheWrite1h;
  return (input * PRICES_PER_MTOK.input + t.output * PRICES_PER_MTOK.output) / 1_000_000;
}

function group(kind: RequestKind): "chat" | "event" | "evening" {
  return kind === "elder" ? "chat" : kind;
}

function kindStats(records: CallRecord[]): KindStats {
  const priced = records.filter((r) => r.tokens !== null);
  const n = Math.max(1, priced.length);
  const sum = (f: (t: TokenBreakdown) => number) =>
    priced.reduce((acc, r) => acc + f(r.tokens!), 0) / n;
  return {
    calls: records.length,
    ok: records.filter((r) => r.ok).length,
    avgTokens: {
      input: sum((t) => t.input),
      cacheRead: sum((t) => t.cacheRead),
      cacheWrite5m: sum((t) => t.cacheWrite5m),
      cacheWrite1h: sum((t) => t.cacheWrite1h),
      output: sum((t) => t.output),
    },
    avgCost: priced.reduce((acc, r) => acc + r.costUsd, 0) / n,
    avgCostNoCache: priced.reduce((acc, r) => acc + noCacheCost(r.tokens!), 0) / n,
  };
}

export function summarize(records: CallRecord[]): ConfigSummary[] {
  const configs = [...new Set(records.map((r) => r.config))];
  return configs.map((config) => {
    const mine = records.filter((r) => r.config === config);
    const byKind: ConfigSummary["byKind"] = {};
    for (const kind of ["chat", "event", "evening"] as const) {
      const ofKind = mine.filter((r) => group(r.kind) === kind);
      if (ofKind.length > 0) byKind[kind] = kindStats(ofKind);
    }
    const full = (pick: (s: KindStats) => number) =>
      byKind.chat && byKind.event && byKind.evening
        ? FULL_USE.chat * pick(byKind.chat) + FULL_USE.evening * pick(byKind.evening) +
          FULL_USE.event * pick(byKind.event)
        : null;
    const answered = (kinds: string[]) =>
      mine.filter((r) => r.tokens !== null && kinds.includes(group(r.kind)))
        .map((r) => r.latencyMs);
    const chatTimes = answered(["chat"]);
    return {
      config,
      calls: mine.length,
      ok: mine.filter((r) => r.ok).length,
      refusals: mine.filter((r) => r.reason === "refusal").length,
      invalid: mine.filter((r) => r.reason === "invalid" || r.reason === "max_tokens").length,
      errors: mine.filter((r) => r.reason === "error" || r.reason === "timeout").length,
      chatLatencyP50: percentile(chatTimes, 50),
      chatLatencyP95: percentile(chatTimes, 95),
      storyLatencyP95: percentile(answered(["event", "evening"]), 95),
      totalCost: mine.reduce((acc, r) => acc + r.costUsd, 0),
      byKind,
      fullUse: full((s) => s.avgCost),
      fullUseNoCache: full((s) => s.avgCostNoCache),
      failedChecks: mine.flatMap((r) =>
        r.checks.filter((c) => !c.pass).map((c) => ({
          scenario: r.scenario,
          turn: r.turn,
          check: c.name,
          note: c.note ?? "",
        }))
      ),
    };
  });
}

const cell = (text: unknown) => String(text ?? "").replaceAll("|", "\\|").replaceAll("\n", " ");
const usd = (n: number | null) => (n === null ? "—" : `$${n.toFixed(n < 0.01 ? 5 : 4)}`);
const tok = (n: number) => Math.round(n).toLocaleString("en-US");

export interface ReportMeta {
  label: string;
  date: string;
  model: string;
  cacheTtl: string;
}

export function markdownReport(meta: ReportMeta, records: CallRecord[]): string {
  const summaries = summarize(records);
  const total = records.reduce((acc, r) => acc + r.costUsd, 0);
  const out: string[] = [
    `# AI eval: ${meta.label}`,
    "",
    `- **Date:** ${meta.date}`,
    `- **Model:** \`${meta.model}\``,
    `- **Configs:** ${summaries.map((s) => `\`${s.config}\``).join(", ")}`,
    `- **Cache TTL for shared blocks:** ${meta.cacheTtl}`,
    `- **Calls:** ${records.length}, costing ${usd(total)} in total`,
    "",
    "Rate the replies in `ratings.csv` (funny 1–5, in character y/n). Gate 1 needs at least 7 of 10 chats in each language rated funny.",
    "",
    "## Summary",
    "",
    "| Config | Calls | Valid | Refusals | Invalid | Errors | Chat reply p50 / p95 | Story p95 | Cost |",
    "|---|---|---|---|---|---|---|---|---|",
    ...summaries.map((s) =>
      `| ${s.config} | ${s.calls} | ${s.ok} (${
        ((100 * s.ok) / Math.max(1, s.calls)).toFixed(1)
      }%) | ` +
      `${s.refusals} | ${s.invalid} | ${s.errors} | ${(s.chatLatencyP50 / 1000).toFixed(1)} s / ` +
      `${(s.chatLatencyP95 / 1000).toFixed(1)} s | ${(s.storyLatencyP95 / 1000).toFixed(1)} s | ` +
      `${usd(s.totalCost)} |`
    ),
    "",
    'Gate 1 needs 95% of chat replies within 5 s. Stories are written at the end of the day, behind a "thinking" animation, so they have no target.',
    "",
    `## Full use per player per day`,
    "",
    `${FULL_USE.chat} chat messages, ${FULL_USE.evening} evening stories and ${FULL_USE.event} surprise events (all 50 Spirit Energy). Target: ${
      usd(TARGET_USD_PER_PLAYER_DAY)
    }.`,
    "",
    "| Config | As measured | If caching never helps | Within target |",
    "|---|---|---|---|",
    ...summaries.map((s) =>
      `| ${s.config} | ${usd(s.fullUse)} | ${usd(s.fullUseNoCache)} | ` +
      `${s.fullUse === null ? "—" : s.fullUse <= TARGET_USD_PER_PLAYER_DAY ? "yes" : "**no**"} |`
    ),
    "",
    "Eval calls run close together, so the cache hits more often than it will with real, spread-out players. Plan with both columns.",
    "",
    "## Tokens per request",
    "",
  ];
  for (const s of summaries) {
    out.push(
      `### ${s.config}`,
      "",
      "| Kind | Calls | New input | Cache read | Cache write | Output | Avg cost | Avg cost, no cache |",
      "|---|---|---|---|---|---|---|---|",
    );
    for (const [kind, k] of Object.entries(s.byKind)) {
      const t = k!.avgTokens;
      out.push(
        `| ${kind} | ${k!.calls} | ${tok(t.input)} | ${tok(t.cacheRead)} | ` +
          `${tok(t.cacheWrite5m + t.cacheWrite1h)} | ${tok(t.output)} | ${usd(k!.avgCost)} | ` +
          `${usd(k!.avgCostNoCache)} |`,
      );
    }
    out.push("");
  }

  const failed = summaries.flatMap((s) => s.failedChecks.map((f) => ({ config: s.config, ...f })));
  out.push("## Failed checks", "");
  if (failed.length === 0) {
    out.push("None.", "");
  } else {
    out.push("| Config | Scenario | Turn | Check | Note |", "|---|---|---|---|---|");
    for (const f of failed) {
      out.push(
        `| ${f.config} | ${f.scenario} | ${f.turn + 1} | ${cell(f.check)} | ${cell(f.note)} |`,
      );
    }
    out.push("");
  }

  out.push("## Transcripts", "");
  for (const s of summaries) {
    out.push(`### ${s.config}`, "");
    const mine = records.filter((r) => r.config === s.config);
    for (const scenario of [...new Set(mine.map((r) => r.scenario))]) {
      const turns = mine.filter((r) => r.scenario === scenario);
      const first = turns[0];
      out.push(`#### ${scenario} (${first.locale}, ${first.tag})`, "");
      for (const r of turns) {
        if (r.player !== null) out.push(`> **Sect Master:** ${r.player}`, ">");
        if (!r.ok && r.output === null) {
          out.push(`> _Failed: ${r.reason}${r.detail ? `, ${r.detail}` : ""}_`, "");
          continue;
        }
        const o = r.output as Record<string, unknown>;
        if (r.kind === "chat" || r.kind === "elder") {
          const extras = [
            `${o.expression}`,
            `mood ${Number(o.mood_change) >= 0 ? "+" : ""}${o.mood_change}`,
            o.wants_action ? `wants: ${o.wants_action}` : null,
            o.safety === "ok" ? null : `**safety: ${o.safety}**`,
          ].filter(Boolean).join(", ");
          out.push(`> **Reply** (${extras}): ${o.reply}`);
          if (o.memory) out.push(`> _Memory: ${o.memory}_`);
        } else {
          out.push("```json", JSON.stringify(o, null, 2), "```");
        }
        out.push("");
      }
    }
  }
  return out.join("\n");
}

function csvField(value: unknown): string {
  const text = String(value ?? "");
  return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

/** One row per reply for people to rate. */
export function ratingsCsv(records: CallRecord[]): string {
  const rows = [[
    "config",
    "scenario",
    "locale",
    "tag",
    "turn",
    "player",
    "reply",
    "funny_1_to_5",
    "in_character_y_n",
    "notes",
  ]];
  for (const r of records) {
    const o = r.output as Record<string, unknown> | null;
    const reply = o === null
      ? `(failed: ${r.reason})`
      : r.kind === "chat" || r.kind === "elder"
      ? o.reply
      : r.kind === "event"
      ? `${o.title}: ${o.story}`
      : o.story;
    rows.push([
      r.config,
      r.scenario,
      r.locale,
      r.tag,
      String(r.turn + 1),
      r.player ?? `(${r.kind})`,
      String(reply),
      "",
      "",
      "",
    ]);
  }
  return rows.map((row) => row.map(csvField).join(",")).join("\n") + "\n";
}
