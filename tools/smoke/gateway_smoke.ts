// End-to-end smoke test of the deployed AI gateway. Signs in anonymously,
// then checks sign-in, validation, a chat line, an Elder question and an
// evening story, asked twice: the second answer is the stored story, free.
// Each run creates one anonymous player and spends 5 Spirit Energy.
//
//   deno run --allow-read=game/config --allow-net=<project host> tools/smoke/gateway_smoke.ts

interface Backend {
  supabase_url: string;
  publishable_key: string;
  functions_region: string;
}

const backend: Backend = JSON.parse(await Deno.readTextFile("game/config/backend.json"));
const functionUrl = `${backend.supabase_url}/functions/v1/ai-gateway`;
const failures: string[] = [];

function check(name: string, pass: boolean, detail = "") {
  console.log(`${pass ? "ok  " : "FAIL"} ${name}${detail ? ` (${detail})` : ""}`);
  if (!pass) failures.push(name);
}

async function signInAnonymously(): Promise<string> {
  const res = await fetch(`${backend.supabase_url}/auth/v1/signup`, {
    method: "POST",
    headers: { apikey: backend.publishable_key, "content-type": "application/json" },
    body: "{}",
  });
  const body = await res.json();
  if (!res.ok || typeof body.access_token !== "string") {
    throw new Error(
      `anonymous sign-in failed with ${res.status}: ${JSON.stringify(body)}. ` +
        "Turn on anonymous sign-ins: Supabase dashboard > Authentication > Sign In / Providers.",
    );
  }
  return body.access_token;
}

async function callGateway(body: unknown, token?: string) {
  const headers: Record<string, string> = {
    apikey: backend.publishable_key,
    "content-type": "application/json",
    "x-region": backend.functions_region,
  };
  if (token) headers.authorization = `Bearer ${token}`;
  const started = performance.now();
  const res = await fetch(functionUrl, { method: "POST", headers, body: JSON.stringify(body) });
  const text = await res.text();
  let json: Record<string, unknown> = {};
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }
  return { status: res.status, json, ms: Math.round(performance.now() - started) };
}

const chat = {
  kind: "chat",
  locale: "en",
  disciple: {
    id: "smoke-lin",
    name: "Lin Xiaohe",
    pronouns: "she",
    quirks: ["afraid_of_chickens"],
    spirit_root: "water",
    realm: "qi_refining",
    mood: 2,
    loyalty: 50,
  },
  recent: [],
  message: "Lin, there is a chicken behind you.",
};

const unsigned = await callGateway(chat);
check("a call without sign-in is refused", unsigned.status === 401, `status ${unsigned.status}`);

const token = await signInAnonymously();
check("anonymous sign-in works", true);

const bad = await callGateway({ ...chat, message: "x".repeat(281) }, token);
check("an over-long message is a bad request", bad.status === 400, `status ${bad.status}`);

const elder = await callGateway(
  { kind: "elder", locale: "vi", recent: [], message: "Trưởng lão, ta nên xây gì trước?" },
  token,
);
check("the Elder answers", elder.status === 200, `status ${elder.status}, ${elder.ms} ms`);
if (elder.json.reason === "disabled") {
  check("AI is on", false, "the ANTHROPIC_API_KEY secret is not set on the function");
}
check(
  "the Elder's reply comes from Claude",
  elder.json.source === "ai",
  `source ${elder.json.source}`,
);
check(
  "the Elder costs 1 Spirit Energy",
  elder.json.spirit_energy_left === 49,
  `left ${elder.json.spirit_energy_left}`,
);
console.log(`     Elder: ${elder.json.reply}`);

const line = await callGateway(chat, token);
check("the disciple answers", line.status === 200, `status ${line.status}, ${line.ms} ms`);
check(
  "the disciple's reply comes from Claude",
  line.json.source === "ai",
  `source ${line.json.source}`,
);
check(
  "the reply has every field",
  ["safety", "reply", "expression", "mood_change", "memory", "wants_action"].every((k) =>
    k in line.json
  ),
);
check(
  "the mood change is within -2..2",
  typeof line.json.mood_change === "number" && Math.abs(line.json.mood_change) <= 2,
);
check(
  "a chat line costs 1 Spirit Energy",
  line.json.spirit_energy_left === 48,
  `left ${line.json.spirit_energy_left}`,
);
console.log(`     Lin: ${line.json.reply}`);
check(
  "the English reply uses no Vietnamese forms of address",
  !/sư phụ|lão phu|đệ tử|chưởng môn/i.test(String(line.json.reply)),
);

// Evening story (3 Spirit Energy) ------------------------------------------------

const allowed: Record<string, string[]> = {
  "smoke-lin": ["train", "rest", "meditate", "cook"],
  "smoke-bao": ["rest", "hide"],
};
const evening = {
  kind: "evening",
  locale: "en",
  game_day: 1,
  sect: { rank: "unknown_mountain", resources: { stones: 30, food: 18, herbs: 1, reputation: 0 } },
  disciples: [
    { card: chat.disciple, allowed_actions: allowed["smoke-lin"] },
    {
      card: {
        ...chat.disciple,
        id: "smoke-bao",
        name: "Bao Tian",
        pronouns: "he",
        quirks: ["dramatic"],
      },
      allowed_actions: allowed["smoke-bao"],
    },
  ],
  relationships: [{ a: "smoke-lin", b: "smoke-bao", score: 3 }],
  facts: [
    { type: "trained", disciple: "smoke-lin", gain: 12, ready: false },
    { type: "worked", disciples: ["smoke-bao"], food: 3, herbs: 1 },
    { type: "ate", food: 2 },
  ],
};

interface Decision {
  disciple_id: string;
  action: string;
}
interface Change {
  change: number;
}

const story = await callGateway(evening, token);
check("the evening story arrives", story.status === 200, `status ${story.status}, ${story.ms} ms`);
check(
  "the story comes from Claude and is new",
  story.json.source === "ai" && story.json.stored === false,
  `source ${story.json.source}, stored ${story.json.stored}`,
);
check(
  "it has a story and a morning report",
  typeof story.json.story === "string" && story.json.story.length > 0 &&
    typeof story.json.morning_report === "string" && story.json.morning_report.length > 0,
);
const decisions = (story.json.decisions ?? []) as Decision[];
check(
  "at most 2 decisions, each an allowed action",
  decisions.length <= 2 && decisions.every((d) => allowed[d.disciple_id]?.includes(d.action)),
  JSON.stringify(decisions.map((d) => `${d.disciple_id}:${d.action}`)),
);
const changes = (story.json.relationship_changes ?? []) as Change[];
check(
  "relationship changes are within -2..2",
  changes.every((c) => c.change !== 0 && Math.abs(c.change) <= 2),
  JSON.stringify(changes.map((c) => c.change)),
);
check(
  "the evening costs 3 Spirit Energy",
  story.json.spirit_energy_left === 45,
  `left ${story.json.spirit_energy_left}`,
);
console.log(`     Story: ${String(story.json.story).slice(0, 160)}…`);

const again = await callGateway(evening, token);
check(
  "asking again returns the stored story",
  again.status === 200 && again.json.stored === true && again.json.story === story.json.story,
  `status ${again.status}, stored ${again.json.stored}`,
);

const energy = await fetch(`${backend.supabase_url}/rest/v1/rpc/spirit_energy_status`, {
  method: "POST",
  headers: {
    apikey: backend.publishable_key,
    authorization: `Bearer ${token}`,
    "content-type": "application/json",
  },
  body: "{}",
});
const status = await energy.json();
check(
  "the stored story was free",
  energy.ok && status.left === 45,
  `status ${energy.status}, left ${status.left}`,
);
check(
  "Spirit Energy shows the evening's price",
  status.costs?.evening === 3,
  `costs ${JSON.stringify(status.costs)}`,
);

if (failures.length > 0) {
  console.error(`\n${failures.length} check(s) failed.`);
  Deno.exit(1);
}
console.log("\nAll smoke checks passed.");
