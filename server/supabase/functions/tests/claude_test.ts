import { assert, assertEquals } from "jsr:@std/assert@1";
import { Anthropic } from "../_shared/deps.ts";
import {
  type CallSettings,
  callStructured,
  type MessagesClient,
  requestBody,
} from "../_shared/claude.ts";
import { buildChat } from "../_shared/prompts.ts";
import type { GatewayRequest } from "../_shared/schemas.ts";

const request: GatewayRequest = {
  kind: "elder",
  locale: "en",
  recent: [],
  message: "What should I build first?",
};
const prompt = buildChat(request, [], { cacheTtl: "5m" });
const settings: CallSettings = {
  model: "claude-haiku-5-5",
  effort: "low",
  thinking: "adaptive",
  timeoutMs: 1000,
};

const usage = {
  input_tokens: 40,
  output_tokens: 60,
  cache_read_input_tokens: 1500,
  cache_creation_input_tokens: 0,
  cache_creation: { ephemeral_5m_input_tokens: 0, ephemeral_1h_input_tokens: 0 },
};

const goodReply = JSON.stringify({
  safety: "ok",
  reply: "Patience the turtle says: the Spirit Field. Hungry disciples cultivate poorly.",
  expression: "thinking",
  mood_change: 0,
  memory: null,
  wants_action: null,
});

function message(
  content: unknown[],
  stopReason = "end_turn",
  stopDetails: unknown = null,
): Anthropic.Message {
  return {
    id: "msg_test",
    type: "message",
    role: "assistant",
    model: "claude-haiku-5-5",
    content,
    stop_reason: stopReason,
    stop_sequence: null,
    stop_details: stopDetails,
    usage,
  } as unknown as Anthropic.Message;
}

/** A fake client that records the request body and returns (or throws) what it is given. */
function fakeClient(result: Anthropic.Message | Error) {
  const sent: Anthropic.MessageCreateParamsNonStreaming[] = [];
  const client: MessagesClient = {
    messages: {
      create(body) {
        sent.push(body);
        return result instanceof Error ? Promise.reject(result) : Promise.resolve(result);
      },
    },
  };
  return { client, sent };
}

Deno.test("a good reply is parsed and its usage kept", async () => {
  const { client } = fakeClient(message([{ type: "text", text: goodReply }]));
  const result = await callStructured(client, prompt, settings);
  assert(result.ok);
  assertEquals(result.value.expression, "thinking");
  assertEquals(result.usage.cache_read_input_tokens, 1500);
});

Deno.test("text is read by block type, after any thinking blocks", async () => {
  const { client } = fakeClient(message([
    { type: "thinking", thinking: "", signature: "sig" },
    { type: "text", text: goodReply },
  ]));
  assert((await callStructured(client, prompt, settings)).ok);
});

Deno.test("the request never sends sampling parameters and ends with the user", () => {
  const body = requestBody(prompt, settings);
  for (const banned of ["temperature", "top_p", "top_k"]) {
    assert(!(banned in body), `${banned} must not be sent`);
  }
  assertEquals(body.messages.at(-1)?.role, "user");
  assertEquals(body.output_config?.effort, "low");
  assertEquals(body.output_config?.format?.type, "json_schema");
  assert(!("parse" in (body.output_config?.format ?? {})));
  assert(!("thinking" in body), "adaptive thinking is the default, so it is omitted");
  assertEquals(requestBody(prompt, { ...settings, thinking: "disabled" }).thinking, {
    type: "disabled",
  });
});

Deno.test("a refusal is a typed failure that keeps its usage", async () => {
  const { client } = fakeClient(
    message([], "refusal", { type: "refusal", category: "general_harms", explanation: "" }),
  );
  const result = await callStructured(client, prompt, settings);
  assert(!result.ok);
  assertEquals(result.reason, "refusal");
  assertEquals(result.detail, "refusal: general_harms");
  assertEquals(result.usage?.output_tokens, 60);
});

Deno.test("max_tokens, non-JSON and off-schema replies are failures", async () => {
  const cut = await callStructured(
    fakeClient(message([{ type: "text", text: "{" }], "max_tokens")).client,
    prompt,
    settings,
  );
  assert(!cut.ok && cut.reason === "max_tokens");

  const prose = await callStructured(
    fakeClient(message([{ type: "text", text: "Hello!" }])).client,
    prompt,
    settings,
  );
  assert(!prose.ok && prose.reason === "invalid" && prose.usage !== null);

  const offSchema = await callStructured(
    fakeClient(message([{ type: "text", text: goodReply.replace('"thinking"', '"bored"') }]))
      .client,
    prompt,
    settings,
  );
  assert(!offSchema.ok && offSchema.reason === "invalid");
});

Deno.test("timeouts and API errors are failures without usage", async () => {
  const timeout = await callStructured(
    fakeClient(new Anthropic.APIConnectionTimeoutError()).client,
    prompt,
    settings,
  );
  assert(!timeout.ok && timeout.reason === "timeout" && timeout.usage === null);

  const broken = await callStructured(
    fakeClient(new Error("socket hang up")).client,
    prompt,
    settings,
  );
  assert(!broken.ok && broken.reason === "error");
});
