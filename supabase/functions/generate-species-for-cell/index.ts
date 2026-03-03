import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { cell_id, biome } = await req.json();

    if (!cell_id || !biome) {
      return new Response(
        JSON.stringify({ error: "Missing cell_id or biome" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseKey) {
      return new Response(
        JSON.stringify({ error: "Missing Supabase configuration" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    const { data: species, error } = await supabase
      .from("species")
      .select("*")
      .eq("biome", biome);

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Deterministic seeding: use cell_id as seed for consistent species selection
    // Hash the cell_id to get a deterministic number
    const hash = hashString(cell_id);
    const seed = hash % 1000;

    // Shuffle species deterministically based on seed
    const shuffled = deterministicShuffle(species || [], seed);

    // Return 3-5 species from this biome for this cell
    const count = 3 + (seed % 3);
    const selectedSpecies = shuffled.slice(0, count);

    return new Response(
      JSON.stringify({
        cell_id,
        biome,
        species: selectedSpecies,
        count: selectedSpecies.length,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

// Simple hash function for deterministic seeding
function hashString(str: string): number {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = (hash << 5) - hash + char;
    hash = hash & hash; // Convert to 32bit integer
  }
  return Math.abs(hash);
}

// Fisher-Yates shuffle with deterministic seed
function deterministicShuffle<T>(array: T[], seed: number): T[] {
  const arr = [...array];
  let random = seed;

  for (let i = arr.length - 1; i > 0; i--) {
    random = (random * 9301 + 49297) % 233280;
    const j = Math.floor((random / 233280) * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }

  return arr;
}
