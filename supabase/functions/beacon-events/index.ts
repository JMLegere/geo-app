import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type",
};

// Unauthenticated endpoint for navigator.sendBeacon() crash telemetry.
// Beacon API cannot set custom headers, so this function uses the service
// role key to insert into app_events. Payload is validated and capped.

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return new Response("method not allowed", {
      status: 405,
      headers: CORS_HEADERS,
    });
  }

  try {
    const body = await req.text();
    if (!body || body.length > 65536) {
      return new Response("payload too large or empty", {
        status: 400,
        headers: CORS_HEADERS,
      });
    }

    const events = JSON.parse(body);
    if (!Array.isArray(events) || events.length === 0 || events.length > 50) {
      return new Response("expected array of 1-50 events", {
        status: 400,
        headers: CORS_HEADERS,
      });
    }

    // Validate each event has required fields.
    const rows = [];
    for (const e of events) {
      if (!e.session_id || !e.category || !e.event) continue;
      rows.push({
        session_id: String(e.session_id).slice(0, 100),
        user_id: e.user_id || null,
        device_id: e.device_id ? String(e.device_id).slice(0, 50) : null,
        category: String(e.category).slice(0, 50),
        event: String(e.event).slice(0, 100),
        data: typeof e.data === "object" ? e.data : {},
        created_at: e.created_at || new Date().toISOString(),
      });
    }

    if (rows.length === 0) {
      return new Response("no valid events", {
        status: 400,
        headers: CORS_HEADERS,
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { error } = await supabase.from("app_events").insert(rows);
    if (error) {
      console.error("insert error:", error);
      return new Response("insert failed", {
        status: 500,
        headers: CORS_HEADERS,
      });
    }

    return new Response("ok", { status: 200, headers: CORS_HEADERS });
  } catch (e) {
    console.error("beacon-events error:", e);
    return new Response("error", { status: 500, headers: CORS_HEADERS });
  }
});
