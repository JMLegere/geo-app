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

interface Provider {
  name: string;
  url: string;
  keyEnv: string;
  model: string;
}

const PROVIDERS: Provider[] = [
  { name: "groq", url: "https://api.groq.com/openai/v1/chat/completions", keyEnv: "GROQ_API_KEY", model: "llama-3.3-70b-versatile" },
  { name: "zen-gpt5nano", url: "https://opencode.ai/zen/v1/chat/completions", keyEnv: "OPENCODE_ZEN_API_KEY", model: "gpt-5-nano" },
  { name: "zen-bigpickle", url: "https://opencode.ai/zen/v1/chat/completions", keyEnv: "OPENCODE_ZEN_API_KEY", model: "big-pickle" },
  { name: "zen-minimax", url: "https://opencode.ai/zen/v1/chat/completions", keyEnv: "OPENCODE_ZEN_API_KEY", model: "minimax-m2.5-free" },
  { name: "zen-mimo", url: "https://opencode.ai/zen/v1/chat/completions", keyEnv: "OPENCODE_ZEN_API_KEY", model: "mimo-v2-flash-free" },
  { name: "zen-nemotron", url: "https://opencode.ai/zen/v1/chat/completions", keyEnv: "OPENCODE_ZEN_API_KEY", model: "nemotron-3-super-free" },
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

function extractJSON(raw: string): string {
  // Strip markdown code fences if present
  let cleaned = raw.trim();
  // Remove ```json ... ``` or ``` ... ```
  const fenceMatch = cleaned.match(/```(?:json)?\s*\n?([\s\S]*?)\n?\s*```/);
  if (fenceMatch) {
    cleaned = fenceMatch[1].trim();
  }
  // Remove BOM
  if (cleaned.charCodeAt(0) === 0xFEFF) {
    cleaned = cleaned.slice(1);
  }
  return cleaned;
}

async function callLLM(
  provider: Provider,
  scientificName: string,
  commonName: string,
  taxonomicClass: string,
  validAnimalClasses?: string[],
): Promise<EnrichmentResponse> {
  const apiKey = Deno.env.get(provider.keyEnv);
  if (!apiKey) throw new Error(`${provider.name} API key not set (${provider.keyEnv})`);

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
- size: one of [${ANIMAL_SIZES.join(", ")}] — FIRST estimate the species' typical adult body mass in grams, THEN pick the category whose weight range contains that mass. Use the WEIGHT RANGE, not the example animals:
    fine (under 50 g): e.g. most insects, hummingbirds, tiny frogs, small geckos
    diminutive (50 g – 500 g): e.g. sparrows, plovers, starlings, mice, chipmunks, small frogs
    tiny (500 g – 4 kg): e.g. pigeons, parrots, squirrels, rats, rabbits, small ducks
    small (4 kg – 25 kg): e.g. foxes, raccoons, eagles, large owls, beavers, house cats
    medium (25 kg – 150 kg): e.g. wolves, deer, big cats (leopard), humans, kangaroos
    large (150 kg – 500 kg): e.g. bears, gorillas, lions, tigers, large ungulates (elk)
    huge (500 kg – 2,000 kg): e.g. moose, rhinos, hippos, giraffes, dolphins
    gargantuan (2 t – 15 t): e.g. elephants, orcas, large sharks
    colossal (over 15 t): e.g. blue whales, whale sharks, sperm whales
    IMPORTANT: A 200 g bird is "diminutive", NOT "tiny" or "small". Always check the weight range first.
- brawn: integer (physical strength/size, 0-90)
- wit: integer (intelligence/cunning, 0-90)  
- speed: integer (speed/agility, 0-90)

CRITICAL: brawn + wit + speed MUST equal exactly 90. Distribute 90 points across the three stats based on real-world characteristics.

Species: ${commonName} (${scientificName})
Taxonomic class: ${taxonomicClass}

Return only valid JSON, no markdown.`;

  const response = await fetch(
    provider.url,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: provider.model,
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
    const err = new Error(`${provider.name} API error ${response.status}: ${errBody}`);
    (err as any).statusCode = response.status;
    if (response.status === 429) {
      (err as any).retryAfter = response.headers.get("retry-after") ?? "60";
    }
    throw err;
  }

  const body = await response.json();
  const text = body?.choices?.[0]?.message?.content;
  if (!text) throw new Error(`Empty ${provider.name} response`);

  const parsed = JSON.parse(extractJSON(text));
  if (!isValidEnrichment(parsed, validAnimalClasses)) {
    throw new Error(
      `Invalid enrichment from ${provider.name} for ${taxonomicClass}: ${JSON.stringify(parsed)}`,
    );
  }
  return parsed;
}

class AllProvidersFailedError extends Error {
  constructor(count: number, species: string) {
    super(`All ${count} providers failed for ${species}`);
  }
}

async function callLLMWithRotation(
  providers: Provider[],
  startIndex: number,
  scientificName: string,
  commonName: string,
  taxonomicClass: string,
  validAnimalClasses?: string[],
): Promise<{ result: EnrichmentResponse; nextIndex: number }> {
  for (let i = 0; i < providers.length; i++) {
    const idx = (startIndex + i) % providers.length;
    const provider = providers[idx];
    try {
      const result = await callLLM(provider, scientificName, commonName, taxonomicClass, validAnimalClasses);
      return { result, nextIndex: idx };
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      console.error(`[enrich] ${provider.name} (${provider.model}) failed for ${scientificName}: ${message}`);
      // Single failure → rotate to next provider immediately
    }
  }
  throw new AllProvidersFailedError(providers.length, scientificName);
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

interface BatchRequest {
  species: EnrichRequest[];
}

interface BatchResponse {
  results: EnrichmentRow[];
  errors: Array<{ definition_id: string; error: string }>;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  const authResponse = await validateAuth(req);
  if (authResponse) return authResponse;

  try {
    const body: BatchRequest = await req.json();
    const { species } = body;

    if (!Array.isArray(species) || species.length === 0) {
      return new Response(
        JSON.stringify({ error: "species array must have at least 1 item" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    if (species.length > 10) {
      return new Response(
        JSON.stringify({ error: "Batch size cannot exceed 10 species" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    for (const sp of species) {
      if (!sp.definition_id || !sp.scientific_name || !sp.common_name || !sp.taxonomic_class) {
        return new Response(
          JSON.stringify({
            error: `Missing required fields for species: ${sp.definition_id ?? "unknown"}`,
          }),
          { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
        );
      }
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const availableProviders = PROVIDERS.filter(p => Deno.env.get(p.keyEnv));
    if (availableProviders.length === 0) {
      return new Response(
        JSON.stringify({ error: "No AI provider API keys configured" }),
        { status: 503, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(supabaseUrl, serviceKey);

    const results: EnrichmentRow[] = [];
    const errors: Array<{ definition_id: string; error: string }> = [];

    let providerIndex = 0;

    for (const sp of species) {
      try {
        // 1. Force re-enrichment: delete existing row so LLM re-classifies.
        if (sp.force) {
          await supabase
            .from("species_enrichment")
            .delete()
            .eq("definition_id", sp.definition_id);
        }

        // 2. Check if already enriched with size field — return as-is.
        const { data: existing } = await supabase
          .from("species_enrichment")
          .select("*")
          .eq("definition_id", sp.definition_id)
          .maybeSingle();

        if (existing && (existing as EnrichmentRow).size) {
          results.push(existing as EnrichmentRow);
          continue;
        }

        const sanitizedClasses = sp.valid_animal_classes?.filter(
          (c) => ANIMAL_CLASSES.includes(c),
        );

        const { result: enrichment, nextIndex } = await callLLMWithRotation(
          availableProviders,
          providerIndex,
          sp.scientific_name,
          sp.common_name,
          sp.taxonomic_class,
          sanitizedClasses,
        );
        providerIndex = nextIndex;
        console.log(`[enrich] ${sp.definition_id} enriched via ${availableProviders[providerIndex].name} (${availableProviders[providerIndex].model})`);

        // isValidEnrichment() is already called inside callLLM() — throws on invalid.
        const row: Omit<EnrichmentRow, "enriched_at"> = {
          definition_id: sp.definition_id,
          animal_class: enrichment.animal_class,
          food_preference: enrichment.food_preference,
          climate: enrichment.climate,
          brawn: enrichment.brawn,
          wit: enrichment.wit,
          speed: enrichment.speed,
          size: enrichment.size,
          // Preserve art_url from existing row when re-enriching (same as single-request).
          art_url: existing ? (existing as EnrichmentRow).art_url : null,
        };

        const { data: upserted, error: upsertError } = await supabase
          .from("species_enrichment")
          .upsert(row, { onConflict: "definition_id" })
          .select()
          .single();

        if (upsertError) {
          throw new Error(`Upsert failed: ${upsertError.message}`);
        }

        results.push(upserted as EnrichmentRow);
      } catch (err) {
        // Per-species error: continue processing remaining species.
        const message = err instanceof Error ? err.message : String(err);
        errors.push({ definition_id: sp.definition_id, error: message });
      }
    }

    const response: BatchResponse = { results, errors };
    return new Response(JSON.stringify(response), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  }
});
