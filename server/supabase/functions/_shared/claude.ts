import { Anthropic } from "./deps.ts";
import type { Effort, Thinking } from "./config.ts";
import { claudeSchema } from "./json_schema.ts";
import type { BuiltPrompt } from "./prompts.ts";

export interface CallSettings {
  model: string;
  effort: Effort;
  /** "adaptive" (the default on Haiku 5.5) or "disabled". Only the eval turns it off. */
  thinking: Thinking;
  timeoutMs: number;
}

export type FailureReason = "refusal" | "max_tokens" | "invalid" | "timeout" | "error";

export type CallResult<T> =
  | { ok: true; value: T; usage: Anthropic.Usage; latencyMs: number }
  | {
    ok: false;
    reason: FailureReason;
    /** Present whenever the API answered, so a failed reply is still costed. */
    usage: Anthropic.Usage | null;
    latencyMs: number;
    detail: string;
  };

/** The subset of the SDK client we use, so tests can pass a fake. */
export interface MessagesClient {
  messages: {
    create(
      body: Anthropic.MessageCreateParamsNonStreaming,
      options?: { timeout?: number; maxRetries?: number },
    ): PromiseLike<Anthropic.Message>;
  };
}

export function requestBody<T>(
  prompt: BuiltPrompt<T>,
  settings: CallSettings,
): Anthropic.MessageCreateParamsNonStreaming {
  // Never sampling parameters (Haiku 5.5 rejects them) and never a prefilled
  // assistant turn: the messages always end with the user's turn. The schema
  // JSON is built once per schema, so the API's 24-hour schema cache keeps hitting.
  return {
    model: settings.model,
    max_tokens: prompt.maxTokens,
    system: prompt.system,
    messages: prompt.messages,
    output_config: {
      effort: settings.effort,
      format: { type: "json_schema", schema: claudeSchema(prompt.schema) },
    },
    ...(settings.thinking === "disabled" ? { thinking: { type: "disabled" as const } } : {}),
  };
}

/**
 * Sends one request and returns the parsed reply or a typed failure. It uses
 * messages.create rather than messages.parse because parse throws on a reply
 * that does not match the schema, and then the usage (and cost) is lost.
 */
export async function callStructured<T>(
  client: MessagesClient,
  prompt: BuiltPrompt<T>,
  settings: CallSettings,
): Promise<CallResult<T>> {
  const started = performance.now();
  const elapsed = () => Math.round(performance.now() - started);
  let message: Anthropic.Message;
  try {
    message = await client.messages.create(requestBody(prompt, settings), {
      timeout: settings.timeoutMs,
      maxRetries: 1,
    });
  } catch (error) {
    if (error instanceof Anthropic.APIConnectionTimeoutError) {
      return { ok: false, reason: "timeout", usage: null, latencyMs: elapsed(), detail: "timeout" };
    }
    const detail = error instanceof Anthropic.APIError
      ? `api error ${error.status ?? "?"}: ${error.message}`
      : String(error);
    return { ok: false, reason: "error", usage: null, latencyMs: elapsed(), detail };
  }

  const latencyMs = elapsed();
  const usage = message.usage;
  if (message.stop_reason === "refusal") {
    const category = message.stop_details?.category ?? "unknown";
    return { ok: false, reason: "refusal", usage, latencyMs, detail: `refusal: ${category}` };
  }
  if (message.stop_reason === "max_tokens") {
    return { ok: false, reason: "max_tokens", usage, latencyMs, detail: "hit max_tokens" };
  }

  // A reply can start with thinking blocks; read the text blocks by type.
  const text = message.content
    .filter((block): block is Anthropic.TextBlock => block.type === "text")
    .map((block) => block.text)
    .join("");
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    return { ok: false, reason: "invalid", usage, latencyMs, detail: "reply was not JSON" };
  }
  const parsed = prompt.schema.safeParse(json);
  if (!parsed.success) {
    const issues = parsed.error.issues.slice(0, 3).map((i) => `${i.path.join(".")}: ${i.message}`);
    return { ok: false, reason: "invalid", usage, latencyMs, detail: issues.join("; ") };
  }
  return { ok: true, value: parsed.data, usage, latencyMs };
}
