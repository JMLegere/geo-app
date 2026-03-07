import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const ANIMAL_CLASSES = [
  "birdOfPrey", "gameBird", "nightbird", "parrot", "songbird", "waterfowl", "woodpecker",
  "bee", "beetle", "butterfly", "cicada", "dragonfly", "landMollusk", "locust", "scorpion", "spider",
  "cartilaginousFish", "cephalopod", "clamsUrchinsAndCrustaceans", "jawlessFish", "lobeFinnedFish", "rayFinnedFish",
  "bat", "carnivore", "hare", "herbivore", "primate", "rodent", "seaMammal", "shrew",
  "amphibian", "crocodile", "lizard", "snake", "turtle",
];

const FOOD_TYPES = ["critter", "fish", "fruit", "grub", "nectar", "veg"];
const CLIMATES = ["tropic", "temperate", "boreal", "frigid"];

interface EnrichRequest {
  definition_id: string;
  scientific_name: string;
  common_name: string;
  taxonomic_class: string;
}

interface EnrichmentRow {
  definition_id: string;
  animal_class: string;
  food_preference: string;
  climate: string;
  brawn: number;
  wit: number;
  speed: number;
  art_url: string | null;
  enriched_at: string;
}

interface GeminiResponse {
  animal_class: string;
  food_preference: string;
  climate: string;
  brawn: number;
  wit: number;
  speed: number;
}

function isValidEnrichment(data: unknown): data is GeminiResponse {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  if (!ANIMAL_CLASSES.includes(d.animal_class as string)) return false;
  if (!FOOD_TYPES.includes(d.food_preference as string)) return false;
  if (!CLIMATES.includes(d.climate as string)) return false;
  const brawn = Number(d.brawn);
  const wit = Number(d.wit);
  const speed = Number(d.speed);
  if (!Number.isInteger(brawn) || brawn < 0) return false;
  if (!Number.isInteger(wit) || wit < 0) return false;
  if (!Number.isInteger(speed) || speed < 0) return false;
  if (brawn + wit + speed !== 90) return false;
  return true;
}

async function callGemini(
  apiKey: string,
  scientificName: string,
  commonName: string,
  taxonomicClass: string,
): Promise<GeminiResponse> {
  const prompt = `You are a wildlife classification expert. Given this species, return a JSON object with EXACTLY these fields:
- animal_class: one of [${ANIMAL_CLASSES.join(", ")}]
- food_preference: one of [${FOOD_TYPES.join(", ")}] (what this animal eats)
- climate: one of [${CLIMATES.join(", ")}] (primary habitat climate zone)
- brawn: integer (physical strength/size, 0-90)
- wit: integer (intelligence/cunning, 0-90)  
- speed: integer (speed/agility, 0-90)

CRITICAL: brawn + wit + speed MUST equal exactly 90. Distribute 90 points across the three stats.

Species: ${commonName} (${scientificName})
Taxonomic class: ${taxonomicClass}

Return only valid JSON, no markdown.`;

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          response_mime_type: "application/json",
          temperature: 0.3,
        },
      }),
    },
  );

  if (!response.ok) {
    const errBody = await response.text();
    const err = new Error(`Gemini API error ${response.status}: ${errBody}`);
    (err as any).statusCode = response.status;
    if (response.status === 429) {
      (err as any).retryAfter = response.headers.get("retry-after") ?? "60";
    }
    throw err;
  }

  const body = await response.json();
  const text = body?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("Empty Gemini response");

  const parsed = JSON.parse(text);
  if (!isValidEnrichment(parsed)) {
    throw new Error(`Invalid enrichment from Gemini: ${JSON.stringify(parsed)}`);
  }
  return parsed;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const body: EnrichRequest = await req.json();
    const { definition_id, scientific_name, common_name, taxonomic_class } = body;

    if (!definition_id || !scientific_name || !common_name || !taxonomic_class) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    // Input length validation — prevent prompt injection and token abuse
    if (definition_id.length > 200 || scientific_name.length > 200 ||
        common_name.length > 200 || taxonomic_class.length > 100) {
      return new Response(
        JSON.stringify({ error: "Field too long" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const geminiKey = Deno.env.get("GEMINI_API_KEY");

    if (!geminiKey) {
      return new Response(
        JSON.stringify({ error: "GEMINI_API_KEY not configured" }),
        { status: 503, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(supabaseUrl, serviceKey);

    const { data: existing } = await supabase
      .from("species_enrichment")
      .select("*")
      .eq("definition_id", definition_id)
      .maybeSingle();

    if (existing) {
      return new Response(JSON.stringify(existing as EnrichmentRow), {
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const enrichment = await callGemini(geminiKey, scientific_name, common_name, taxonomic_class);

    const row: Omit<EnrichmentRow, "enriched_at"> = {
      definition_id,
      animal_class: enrichment.animal_class,
      food_preference: enrichment.food_preference,
      climate: enrichment.climate,
      brawn: enrichment.brawn,
      wit: enrichment.wit,
      speed: enrichment.speed,
      art_url: null,
    };

    const { data: inserted, error: insertError } = await supabase
      .from("species_enrichment")
      .insert(row)
      .select()
      .single();

    if (insertError) {
      if (insertError.code === "23505") {
        const { data: concurrent } = await supabase
          .from("species_enrichment")
          .select("*")
          .eq("definition_id", definition_id)
          .maybeSingle();
        return new Response(JSON.stringify(concurrent), {
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
      }
      throw new Error(`Insert failed: ${insertError.message}`);
    }

    return new Response(JSON.stringify(inserted), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    const statusCode = (err as any).statusCode ?? 500;
    const headers: Record<string, string> = {
      ...CORS_HEADERS,
      "Content-Type": "application/json",
    };
    // Forward Retry-After header from Gemini 429 responses so clients can
    // back off appropriately instead of hammering the free-tier quota.
    if (statusCode === 429) {
      const retryAfter = (err as any).retryAfter;
      if (retryAfter) {
        headers["Retry-After"] = String(retryAfter);
      }
    }
    return new Response(
      JSON.stringify({ error: message, statusCode }),
      { status: statusCode, headers },
    );
  }
});
