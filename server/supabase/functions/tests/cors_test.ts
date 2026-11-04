import { assertEquals } from "jsr:@std/assert@1";
import { allowedOrigins, withCors } from "../ai-gateway/cors.ts";

const origins = allowedOrigins(undefined);
const app = withCors(() => Promise.resolve(Response.json({ ok: true })), origins);

function request(method: string, origin?: string): Request {
  return new Request("http://localhost/ai-gateway", {
    method,
    headers: origin ? { origin } : {},
  });
}

Deno.test("the game's own page gets a preflight answer and its origin echoed", async () => {
  const preflight = await app(request("OPTIONS", "https://haobui14.github.io"));
  assertEquals(preflight.status, 204);
  assertEquals(
    preflight.headers.get("access-control-allow-origin"),
    "https://haobui14.github.io",
  );
  const res = await app(request("POST", "https://haobui14.github.io"));
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("access-control-allow-origin"), "https://haobui14.github.io");
});

Deno.test("other websites are turned away", async () => {
  assertEquals((await app(request("OPTIONS", "https://evil.example"))).status, 403);
  assertEquals((await app(request("POST", "https://evil.example"))).status, 403);
});

Deno.test("calls without an Origin pass (sign-in is still required)", async () => {
  const res = await app(request("POST"));
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("access-control-allow-origin"), null);
});

Deno.test("ALLOWED_ORIGINS replaces the defaults", () => {
  assertEquals(
    [...allowedOrigins(" https://a.example , https://b.example ")],
    ["https://a.example", "https://b.example"],
  );
  assertEquals(allowedOrigins("").has("https://haobui14.github.io"), true);
});
