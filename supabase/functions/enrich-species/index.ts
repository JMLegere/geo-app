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

const FOOD_TYPES = ["critter", "fish", "fruit", "grub", "nectar", "seed", "veg"];
const CLIMATES = ["tropic", "temperate", "boreal", "frigid"];
const ANIMAL_SIZES = [
  "fine", "diminutive", "tiny", "small", "medium", "large", "huge", "gargantuan", "colossal",
];

interface EnrichRequest {
  definition_id: string;
  scientific_name: string;
  common_name: string;
  taxonomic_class: string;
  valid_animal_classes?: string[];
  force?: boolean;
}

interface EnrichmentRow {
  definition_id: string;
  animal_class: string;
  food_preference: string;
  climate: string;
  brawn: number;
  wit: number;
  speed: number;
  size: string;
  art_url: string | null;
  enriched_at: string;
}

interface EnrichmentResponse {
  animal_class: string;
  food_preference: string;
  climate: string;
  brawn: number;
  wit: number;
  speed: number;
  size: string;
}

function isValidEnrichment(
  data: unknown,
  validAnimalClasses?: string[],
): data is EnrichmentResponse {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  if (!ANIMAL_CLASSES.includes(d.animal_class as string)) return false;
  if (!FOOD_TYPES.includes(d.food_preference as string)) return false;
  if (!CLIMATES.includes(d.climate as string)) return false;
  if (!ANIMAL_SIZES.includes(d.size as string)) return false;
  const brawn = Number(d.brawn);
  const wit = Number(d.wit);
  const speed = Number(d.speed);
  if (!Number.isInteger(brawn) || brawn < 0) return false;
  if (!Number.isInteger(wit) || wit < 0) return false;
  if (!Number.isInteger(speed) || speed < 0) return false;
  if (brawn + wit + speed !== 90) return false;

  if (validAnimalClasses?.length &&
      !validAnimalClasses.includes(d.animal_class as string)) {
    return false;
  }
  return true;
}

async function callLLM(
  apiKey: string,
  scientificName: string,
  commonName: string,
  taxonomicClass: string,
  validAnimalClasses?: string[],
): Promise<EnrichmentResponse> {
  const classConstraint = validAnimalClasses?.length
    ? `CRITICAL: You MUST pick animal_class from ONLY these: [${validAnimalClasses.join(", ")}]`
    : `- animal_class: one of [${ANIMAL_CLASSES.join(", ")}]`;

  const prompt = `You are a wildlife classification expert. Given this species, return a JSON object with EXACTLY these fields:
${classConstraint}
- food_preference: one of [${FOOD_TYPES.join(", ")}] — pick based on the species' PRIMARY real-world diet:
    critter = small animals (mice, lizards, frogs, small birds — for predators)
    fish = fish, aquatic prey (for piscivores)
    fruit = fruit, berries (for frugivores)
    grub = insects, larvae, worms, invertebrates (for insectivores)
    nectar = nectar, pollen (for nectarivores like hummingbirds, bees)
    seed = seeds, grains, nuts, kernels (for granivores like sparrows, finches, rodents)
    veg = leaves, roots, grass, plant matter that is NOT fruit/seed/nectar (for herbivores/folivores)
- climate: one of [${CLIMATES.join(", ")}] (primary habitat climate zone)
- size: one of [${ANIMAL_SIZES.join(", ")}] — pick based on adult body mass:
    fine = insects, tiny invertebrates (< 50 g)
    diminutive = small insects, frogs, mice (50-500 g)
    tiny = squirrels, rats, small birds (500 g - 4 kg)
    small = foxes, rabbits, medium dogs (4-25 kg)
    medium = wolves, large cats, deer (25-150 kg)
    large = bears, big cats, large ungulates (150-500 kg)
    huge = rhinos, hippos, small cetaceans (500-2,000 kg)
    gargantuan = elephants, large cetaceans (2-15 t)
    colossal = blue whales, colossal marine life (15+ t)
- brawn: integer (physical strength/size, 0-90)
- wit: integer (intelligence/cunning, 0-90)  
- speed: integer (speed/agility, 0-90)

CRITICAL: brawn + wit + speed MUST equal exactly 90. Distribute 90 points across the three stats based on real-world characteristics.

Species: ${commonName} (${scientificName})
Taxonomic class: ${taxonomicClass}

Return only valid JSON, no markdown.`;

  const response = await fetch(
    "https://api.groq.com/openai/v1/chat/completions",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [
          {
            role: "system",
            content: "You are a wildlife classification expert. Always respond with valid JSON only, no markdown fences.",
          },
          { role: "user", content: prompt },
        ],
        temperature: 0.3,
        response_format: { type: "json_object" },
      }),
    },
  );

  if (!response.ok) {
    const errBody = await response.text();
    const err = new Error(`Groq API error ${response.status}: ${errBody}`);
    (err as any).statusCode = response.status;
    if (response.status === 429) {
      (err as any).retryAfter = response.headers.get("retry-after") ?? "60";
    }
    throw err;
  }

  const body = await response.json();
  const text = body?.choices?.[0]?.message?.content;
  if (!text) throw new Error("Empty Groq response");

  const parsed = JSON.parse(text);
  if (!isValidEnrichment(parsed, validAnimalClasses)) {
    throw new Error(
      `Invalid enrichment from Groq for ${taxonomicClass}: ${JSON.stringify(parsed)}`,
    );
  }
  return parsed;
}

async function validateAuth(req: Request): Promise<Response | null> {
  const authHeader = req.headers.get("authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({ error: "Missing or invalid authorization header" }),
      { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  }
  const token = authHeader.replace("Bearer ", "");
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
  );
  const { error } = await supabase.auth.getUser(token);
  if (error) {
    return new Response(
      JSON.stringify({ error: "Invalid or expired token" }),
      { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  }
  return null;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  const authResponse = await validateAuth(req);
  if (authResponse) return authResponse;

  try {
    const body: EnrichRequest = await req.json();
    const { definition_id, scientific_name, common_name, taxonomic_class, valid_animal_classes, force } = body;

    if (!definition_id || !scientific_name || !common_name || !taxonomic_class) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    if (definition_id.length > 200 || scientific_name.length > 200 ||
        common_name.length > 200 || taxonomic_class.length > 100) {
      return new Response(
        JSON.stringify({ error: "Field too long" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    const sanitizedClasses = valid_animal_classes?.filter(
      (c) => ANIMAL_CLASSES.includes(c),
    );

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const groqKey = Deno.env.get("GROQ_API_KEY");

    if (!groqKey) {
      return new Response(
        JSON.stringify({ error: "GROQ_API_KEY not configured" }),
        { status: 503, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(supabaseUrl, serviceKey);

    // Force re-enrichment: delete existing row so the LLM re-classifies.
    if (force) {
      await supabase
        .from("species_enrichment")
        .delete()
        .eq("definition_id", definition_id);
    }

    const { data: existing } = await supabase
      .from("species_enrichment")
      .select("*")
      .eq("definition_id", definition_id)
      .maybeSingle();

    // If row exists and already has size, return it as-is.
    // If row exists but has no size (enriched before size field was added),
    // fall through to re-enrich so the size gets populated.
    if (existing && (existing as EnrichmentRow).size) {
      return new Response(JSON.stringify(existing as EnrichmentRow), {
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const enrichment = await callLLM(groqKey, scientific_name, common_name, taxonomic_class, sanitizedClasses);

    const row: Omit<EnrichmentRow, "enriched_at"> = {
      definition_id,
      animal_class: enrichment.animal_class,
      food_preference: enrichment.food_preference,
      climate: enrichment.climate,
      brawn: enrichment.brawn,
      wit: enrichment.wit,
      speed: enrichment.speed,
      size: enrichment.size,
      art_url: existing ? (existing as EnrichmentRow).art_url : null,
    };

    // Upsert: inserts new row or updates existing row missing size.
    const { data: upserted, error: upsertError } = await supabase
      .from("species_enrichment")
      .upsert(row, { onConflict: "definition_id" })
      .select()
      .single();

    if (upsertError) {
      throw new Error(`Upsert failed: ${upsertError.message}`);
    }

    return new Response(JSON.stringify(upserted), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    const statusCode = (err as any).statusCode ?? 500;
    const headers: Record<string, string> = {
      ...CORS_HEADERS,
      "Content-Type": "application/json",
    };
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
