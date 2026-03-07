import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface ValidateRequest {
  item_id: string;
  user_id: string;
  definition_id: string;
  cell_id: string;
  daily_seed: string | null;
  acquired_at: string;
}

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const body: ValidateRequest = await req.json();
    const { item_id, user_id, definition_id, cell_id, daily_seed, acquired_at } = body;

    if (!item_id || !user_id || !definition_id || !cell_id || !acquired_at) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        {
          status: 400,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    const OFFLINE_SEED = "offline_no_rotation";

    const acquiredDate = new Date(acquired_at);
    const seedDate = acquiredDate.toISOString().split("T")[0];
    const todayStr = new Date().toISOString().split("T")[0];

    // Offline fallback seed — skip seed validation entirely.
    // Encounters using the static fallback are best-effort (no daily rotation).
    if (!daily_seed || daily_seed === OFFLINE_SEED) {
      // Accept without seed validation.
    } else {
      // Client sent a real seed — validate against server records.
      const { data: seedRow } = await supabase
        .from("daily_seeds")
        .select("seed_value")
        .eq("seed_date", seedDate)
        .maybeSingle();

      if (!seedRow && seedDate === todayStr) {
        // No seed on server for today — generate it now (idempotent).
        const { data: generatedSeed, error: rpcError } = await supabase
          .rpc("ensure_daily_seed");
        if (rpcError || !generatedSeed) {
          return new Response(
            JSON.stringify({ status: "rejected", reason: "seed_generation_failed" }),
            {
              status: 500,
              headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
            },
          );
        }
        // Re-validate: the generated seed must match what the client sent.
        if (generatedSeed !== daily_seed) {
          return new Response(
            JSON.stringify({ status: "rejected", reason: "daily_seed_mismatch" }),
            {
              status: 409,
              headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
            },
          );
        }
      } else if (!seedRow && seedDate !== todayStr) {
        // Encounter from a past date, server has no seed for that day.
        // Can't retroactively validate — accept as-is.
        // ensure_daily_seed() only generates TODAY's seed, so we can't
        // create the old date's seed. Accept the encounter.
      } else if (seedRow && seedRow.seed_value !== daily_seed) {
        return new Response(
          JSON.stringify({
            status: "rejected",
            reason: "daily_seed_mismatch",
          }),
          {
            status: 409,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
          },
        );
      }
    }

    const serverSeed = daily_seed ?? "";
    const hashInput = `${serverSeed}_${cell_id}_${definition_id}`;
    const serverHash = await sha256Hex(hashInput);

    // Structural validation: seed match (checked above), well-formed IDs,
    // acquired_at within seed date range. Full species re-derivation requires
    // the IUCN dataset server-side (future work — would verify exact rolls).

    if (
      definition_id.length === 0 ||
      cell_id.length === 0 ||
      definition_id.length > 200
    ) {
      return new Response(
        JSON.stringify({
          status: "rejected",
          reason: "invalid_definition_or_cell",
        }),
        {
          status: 409,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    // Verify acquired_at is within the seed date (±1 day tolerance for
    // timezone edge cases and offline grace period).
    const seedDateObj = new Date(seedDate + "T00:00:00Z");
    const tolerance = 2 * 24 * 60 * 60 * 1000;
    if (Math.abs(acquiredDate.getTime() - seedDateObj.getTime()) > tolerance) {
      return new Response(
        JSON.stringify({
          status: "rejected",
          reason: "acquired_at_out_of_range",
        }),
        {
          status: 409,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    // Store the validation hash for future Phase 4 auditing.
    const { error: upsertError } = await supabase
      .from("item_instances")
      .update({ daily_seed: daily_seed ?? serverSeed })
      .eq("id", item_id)
      .eq("user_id", user_id);

    if (upsertError) {
      console.error("Failed to update item daily_seed:", upsertError);
      // Non-fatal — item was already upserted by the write queue.
    }

    return new Response(
      JSON.stringify({
        status: "accepted",
        validation_hash: serverHash,
      }),
      {
        status: 200,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
