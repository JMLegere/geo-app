import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

const MAX_BODY_BYTES = 256 * 1024;
const MAX_LOGS = 100;
const MAX_SPANS = 100;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const TRACE_ID_RE = /^[0-9a-f]{32}$/;
const SPAN_ID_RE = /^[0-9a-f]{16}$/;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function text(value: unknown, fallback: string, max: number): string {
  if (typeof value !== "string" || value.trim().length === 0) return fallback;
  return value.slice(0, max);
}

function nullableText(value: unknown, max: number): string | null {
  if (typeof value !== "string" || value.trim().length === 0) return null;
  return value.slice(0, max);
}

function uuid(value: unknown): string {
  return typeof value === "string" && UUID_RE.test(value)
    ? value
    : crypto.randomUUID();
}

function nullableUuid(value: unknown): string | null {
  return typeof value === "string" && UUID_RE.test(value) ? value : null;
}

function traceId(value: unknown): string | null {
  if (typeof value === "string" && TRACE_ID_RE.test(value)) return value;
  return null;
}

function requiredTraceId(value: unknown): string {
  return traceId(value) ?? crypto.randomUUID().replaceAll("-", "");
}

function spanId(value: unknown): string | null {
  if (typeof value === "string" && SPAN_ID_RE.test(value)) return value;
  return null;
}

function requiredSpanId(value: unknown): string {
  return spanId(value) ?? crypto.randomUUID().replaceAll("-", "").slice(0, 16);
}

function isoTime(value: unknown, fallback: string): string {
  if (typeof value !== "string") return fallback;
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? new Date(parsed).toISOString() : fallback;
}

function jsonObject(value: unknown): Record<string, unknown> {
  return isRecord(value) ? value : {};
}

function jsonArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function severity(value: unknown): string {
  const candidate = text(value, "INFO", 16).toUpperCase();
  return ["TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL"].includes(candidate)
    ? candidate
    : "INFO";
}

function spanKind(value: unknown): string {
  const candidate = text(value, "internal", 16).toLowerCase();
  return ["internal", "client", "server", "producer", "consumer"].includes(candidate)
    ? candidate
    : "internal";
}

function spanStatus(value: unknown): string {
  const candidate = text(value, "unset", 16).toLowerCase();
  return ["unset", "ok", "error"].includes(candidate) ? candidate : "unset";
}

function resourceValue(
  resource: Record<string, unknown>,
  row: Record<string, unknown>,
  key: string,
  fallback: string,
): string {
  return text(row[key] ?? resource[key], fallback, 120);
}

function nullableResourceValue(
  resource: Record<string, unknown>,
  row: Record<string, unknown>,
  key: string,
): string | null {
  return nullableText(row[key] ?? resource[key], 120);
}

function eventCategory(row: Record<string, unknown>): string {
  const explicit = nullableText(row.category, 80);
  if (explicit != null) return explicit;
  const name = text(row.event_name ?? row.event, "app.event", 160);
  return name.includes(".") ? name.split(".")[0].slice(0, 80) : "app";
}

function eventName(row: Record<string, unknown>): string {
  return text(row.event_name ?? row.event, "app.event", 160);
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(JSON.stringify({ ok: true }), { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), {
      status: 405,
      headers: CORS_HEADERS,
    });
  }

  try {
    const body = await req.text();
    if (!body || body.length > MAX_BODY_BYTES) {
      return new Response(JSON.stringify({ error: "invalid_body_size" }), {
        status: 400,
        headers: CORS_HEADERS,
      });
    }

    const payload = JSON.parse(body);
    if (!isRecord(payload)) {
      return new Response(JSON.stringify({ error: "expected_envelope" }), {
        status: 400,
        headers: CORS_HEADERS,
      });
    }

    const now = new Date().toISOString();
    const resource = jsonObject(payload.resource);
    const logs = jsonArray(payload.logs).filter(isRecord).slice(0, MAX_LOGS);
    const spans = jsonArray(payload.spans).filter(isRecord).slice(0, MAX_SPANS);

    if (logs.length === 0 && spans.length === 0) {
      return new Response(JSON.stringify({ error: "empty_envelope" }), {
        status: 400,
        headers: CORS_HEADERS,
      });
    }

    const logRows = logs.map((entry) => ({
      occurred_at: isoTime(entry.occurred_at ?? entry.created_at, now),
      observed_at: now,
      service_name: resourceValue(resource, entry, "service_name", "earthnova-app"),
      service_version: nullableResourceValue(resource, entry, "service_version"),
      deployment_environment: nullableResourceValue(resource, entry, "deployment_environment"),
      platform: nullableResourceValue(resource, entry, "platform"),
      session_id: uuid(entry.session_id),
      device_id: nullableText(entry.device_id, 120),
      user_id: nullableUuid(entry.user_id),
      trace_id: traceId(entry.trace_id),
      span_id: spanId(entry.span_id),
      trace_flags: text(entry.trace_flags, "01", 2),
      severity_text: severity(entry.severity_text),
      category: eventCategory(entry),
      event_name: eventName(entry),
      body: nullableText(entry.body ?? jsonObject(entry.data).msg, 4000),
      attributes: jsonObject(entry.attributes ?? entry.data),
      dropped_attributes_count: 0,
    }));

    const spanRows = spans.map((entry) => ({
      trace_id: requiredTraceId(entry.trace_id),
      span_id: requiredSpanId(entry.span_id),
      parent_span_id: spanId(entry.parent_span_id),
      span_name: text(entry.span_name ?? entry.name, "app.span", 160),
      span_kind: spanKind(entry.span_kind),
      started_at: isoTime(entry.started_at, now),
      ended_at: entry.ended_at == null ? null : isoTime(entry.ended_at, now),
      status_code: spanStatus(entry.status_code),
      status_message: nullableText(entry.status_message, 4000),
      service_name: resourceValue(resource, entry, "service_name", "earthnova-app"),
      service_version: nullableResourceValue(resource, entry, "service_version"),
      deployment_environment: nullableResourceValue(resource, entry, "deployment_environment"),
      platform: nullableResourceValue(resource, entry, "platform"),
      session_id: uuid(entry.session_id),
      device_id: nullableText(entry.device_id, 120),
      user_id: nullableUuid(entry.user_id),
      attributes: jsonObject(entry.attributes),
      events: jsonArray(entry.events),
      dropped_attributes_count: 0,
    }));

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    if (logRows.length > 0) {
      const { error } = await supabase.from("telemetry_logs").insert(logRows);
      if (error) throw error;
    }

    if (spanRows.length > 0) {
      const { error } = await supabase.from("telemetry_spans").insert(spanRows);
      if (error) throw error;
    }

    return new Response(
      JSON.stringify({ ok: true, inserted_logs: logRows.length, inserted_spans: spanRows.length }),
      { status: 200, headers: CORS_HEADERS },
    );
  } catch (error) {
    console.error("telemetry-ingest error:", error);
    return new Response(JSON.stringify({ error: "ingest_failed" }), {
      status: 500,
      headers: CORS_HEADERS,
    });
  }
});
