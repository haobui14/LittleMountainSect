// End-to-end smoke test of the deployed AI gateway. Signs in anonymously,
// then checks sign-in, validation, a chat line and an Elder question.
// Each run creates one anonymous player and spends 2 Spirit Energy.
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

if (failures.length > 0) {
  console.error(`\n${failures.length} check(s) failed.`);
  Deno.exit(1);
}
console.log("\nAll smoke checks passed.");
