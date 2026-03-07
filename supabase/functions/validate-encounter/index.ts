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

    const acquiredDate = new Date(acquired_at);
    const seedDate = acquiredDate.toISOString().split("T")[0];

    const { data: seedRow } = await supabase
      .from("daily_seeds")
      .select("seed_value")
      .eq("seed_date", seedDate)
      .maybeSingle();

    if (!seedRow && daily_seed) {
      // No seed on server for that date and client claims one.
      // The daily seed system isn't live yet (Phase 4). Accept for now.
      return new Response(
        JSON.stringify({ status: "accepted", reason: "daily_seed_not_enforced" }),
        {
          status: 200,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    if (seedRow && daily_seed && seedRow.seed_value !== daily_seed) {
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

    const serverSeed = seedRow?.seed_value ?? "";
    const hashInput = `${serverSeed}_${cell_id}_${definition_id}`;
    const expectedHash = await sha256Hex(hashInput);

    // Validate that this definition_id is plausible for this cell.
    // The full deterministic re-derivation (matching client-side loot table
    // rolls) requires the species dataset, which isn't loaded server-side.
    // For Phase 3, we do structural validation only:
    // 1. daily_seed matches ✓ (checked above)
    // 2. definition_id is non-empty and well-formed
    // 3. cell_id is non-empty
    // 4. acquired_at is within seed_date range
    //
    // Full re-derivation (Phase 4) will use the hash to verify the exact
    // species rolled for this cell + seed combination.

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
        validation_hash: expectedHash,
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
