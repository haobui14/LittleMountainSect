// CORS with an allowlist. Browsers only get the response if the game's page
// comes from an allowed origin. CORS is not authentication: every request
// still needs a valid sign-in, so calls without an Origin (scripts, tests) pass.

const DEFAULT_ORIGINS = [
  "https://haobui14.github.io",
  "http://localhost:8060",
  "http://127.0.0.1:8060",
];

/** Origins from the ALLOWED_ORIGINS secret (comma-separated), or the defaults. */
export function allowedOrigins(setting: string | undefined): Set<string> {
  const list = setting?.split(",").map((o) => o.trim()).filter((o) => o.length > 0);
  return new Set(list && list.length > 0 ? list : DEFAULT_ORIGINS);
}

const ALLOW_HEADERS = "authorization, x-client-info, apikey, content-type, x-region";

export function withCors(
  handler: (req: Request) => Promise<Response>,
  origins: Set<string>,
): (req: Request) => Promise<Response> {
  return async (req) => {
    const origin = req.headers.get("origin");
    const allowed = origin !== null && origins.has(origin);

    if (req.method === "OPTIONS") {
      if (!allowed) return new Response(null, { status: 403 });
      return new Response(null, {
        status: 204,
        headers: {
          "access-control-allow-origin": origin,
          "access-control-allow-methods": "POST, OPTIONS",
          "access-control-allow-headers": ALLOW_HEADERS,
          "access-control-max-age": "86400",
          "vary": "Origin",
        },
      });
    }
    if (origin !== null && !allowed) {
      return Response.json({ error: "origin_not_allowed" }, { status: 403 });
    }

    const response = await handler(req);
    if (!allowed) return response;
    const headers = new Headers(response.headers);
    headers.set("access-control-allow-origin", origin);
    headers.append("vary", "Origin");
    return new Response(response.body, { status: response.status, headers });
  };
}
