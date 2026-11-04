import { z } from "./deps.ts";

// Turns a zod schema into the JSON schema Claude's structured outputs accept.
//
// We don't use the SDK's zodOutputFormat here: in @anthropic-ai/sdk 1.4.0 it
// keeps only a few keys and moves everything else, including `enum`, into the
// description, so enums are no longer enforced. The API does support `enum`,
// `const`, `anyOf`, `allOf` and `$ref`; it does not support numeric or length
// limits, which we drop (validate.ts clamps those values instead).

const DROPPED_KEYS = new Set([
  "$schema",
  "default",
  "minimum",
  "maximum",
  "exclusiveMinimum",
  "exclusiveMaximum",
  "multipleOf",
  "minLength",
  "maxLength",
  "pattern",
  "minItems",
  "maxItems",
  "uniqueItems",
]);

const SUPPORTED_FORMATS = new Set([
  "date-time",
  "time",
  "date",
  "duration",
  "email",
  "hostname",
  "uri",
  "ipv4",
  "ipv6",
  "uuid",
]);

type Json = null | boolean | number | string | Json[] | { [key: string]: Json };

function clean(node: Json): Json {
  if (Array.isArray(node)) return node.map(clean);
  if (node === null || typeof node !== "object") return node;

  const out: { [key: string]: Json } = {};
  for (const [key, value] of Object.entries(node)) {
    if (DROPPED_KEYS.has(key)) continue;
    if (key === "format" && !SUPPORTED_FORMATS.has(String(value))) continue;
    if (key === "properties" || key === "$defs") {
      out[key] = Object.fromEntries(
        Object.entries(value as { [key: string]: Json }).map(([k, v]) => [k, clean(v)]),
      );
    } else if (key === "oneOf") {
      out.anyOf = clean(value);
    } else if (key === "type" && Array.isArray(value)) {
      // ["string", "null"] becomes anyOf, the form the docs list as supported.
      out.anyOf = value.map((type) => ({ type }));
    } else {
      out[key] = clean(value);
    }
  }
  if (out.type === "object") out.additionalProperties = false;
  return out;
}

const cache = new WeakMap<object, { [key: string]: Json }>();

/** The JSON schema to send as output_config.format.schema. Built once per schema. */
export function claudeSchema(schema: z.ZodType): { [key: string]: Json } {
  let result = cache.get(schema);
  if (!result) {
    result = clean(z.toJSONSchema(schema) as Json) as { [key: string]: Json };
    cache.set(schema, result);
  }
  return result;
}
