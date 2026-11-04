// AI gateway Edge Function. Players' clients call this for every AI request;
// it is the only place the Claude API key is used.
//
// Secrets: ANTHROPIC_API_KEY (required for AI; without it every request gets a
// written line), AI_MODEL (optional override), ALLOWED_ORIGINS (optional,
// comma-separated; see cors.ts for the defaults).

import { withSupabase } from "npm:@supabase/server@1.9.2";
import type { CallSettings } from "../_shared/claude.ts";
import {
  DEFAULT_CACHE_TTL,
  DEFAULT_EFFORT,
  DEFAULT_MODEL,
  REQUEST_TIMEOUT_MS,
} from "../_shared/config.ts";
import { Anthropic } from "../_shared/deps.ts";
import { allowedOrigins, withCors } from "./cors.ts";
import { type RpcClient, supabaseDb } from "./db.ts";
import { handleGateway } from "./handler.ts";

const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
const claude = apiKey ? new Anthropic({ apiKey, maxRetries: 1 }) : null;

const settings: CallSettings & { cacheTtl: typeof DEFAULT_CACHE_TTL } = {
  model: Deno.env.get("AI_MODEL") || DEFAULT_MODEL,
  effort: DEFAULT_EFFORT,
  thinking: "adaptive",
  timeoutMs: REQUEST_TIMEOUT_MS,
  cacheTtl: DEFAULT_CACHE_TTL,
};

// withSupabase checks the player's sign-in (auth: "user") and gives us an
// admin client using the project's secret key. CORS is handled by withCors,
// because the gateway only answers the game's own pages.
const gateway = withSupabase(
  { auth: "user", cors: "disabled" },
  (req, ctx) =>
    handleGateway(req, ctx.userClaims!.id, {
      db: supabaseDb(ctx.supabaseAdmin as unknown as RpcClient),
      claude,
      settings,
    }),
);

export default {
  fetch: withCors(gateway, allowedOrigins(Deno.env.get("ALLOWED_ORIGINS"))),
};
