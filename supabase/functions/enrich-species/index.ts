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

const ART_BUCKET = "species-art";
const GEMINI_IMAGE_MODEL = "gemini-2.5-flash-image";
const ART_MAX_RETRIES = 3;
const ART_BASE_DELAY_MS = 2000;

function buildArtPrompt(
  commonName: string,
  scientificName: string,
  assetType: "icon" | "illustration",
  enrichment?: { climate?: string; brawn?: number; wit?: number; speed?: number },
): string {
  if (assetType === "icon") {
    return `Generate an image: Cute chibi-style character icon of a ${commonName} (${scientificName}). Simple, adorable, round proportions, expressive eyes, clean outline. Transparent background, centered, facing slightly left. Style: Pokemon PC box sprite, soft colors, no text, no shadows, no ground. 96x96 pixels.`;
  }

  let poseDirection = "natural resting pose, alert but relaxed";
  if (enrichment?.brawn != null && enrichment?.wit != null && enrichment?.speed != null) {
    const max = Math.max(enrichment.brawn, enrichment.wit, enrichment.speed);
    if (enrichment.brawn === max) poseDirection = "powerful stance, grounded, imposing";
    else if (enrichment.speed === max) poseDirection = "dynamic motion, leaping, wind-swept, mid-stride";
    else if (enrichment.wit === max) poseDirection = "alert and observant, clever posture, head tilted";
  }

  let climateLighting = "Soft natural daylight, gentle warmth";
  switch (enrichment?.climate) {
    case "tropic": climateLighting = "Warm golden tropical light, lush greens"; break;
    case "boreal": climateLighting = "Cool crisp northern light, muted tones"; break;
    case "frigid": climateLighting = "Cold blue-white arctic light, stark contrast"; break;
  }

  return `Generate an image: Professional Pokemon TCG-style watercolor illustration of a ${commonName} (${scientificName}). Pose: ${poseDirection}. Composition: Full body, 3/4 view, slightly off-center, breathing room. Background: Soft atmospheric natural scene, impressionistic, not competing with subject. ${climateLighting}. Style: Watercolor with visible brushstrokes, soft edges, translucent layers, luminous quality. Moderate saturation. Soft diffused lighting. No text, no labels, no borders, no card frame. 512x512 pixels.`;
}

async function generateAndUploadArt(
  supabase: any,
  supabaseUrl: string,
  geminiKey: string,
  definitionId: string,
  scientificName: string,
  commonName: string,
  assetType: "icon" | "illustration",
  enrichment?: { climate?: string; brawn?: number; wit?: number; speed?: number },
): Promise<string | null> {
  const fileName = assetType === "icon"
    ? `${definitionId}_icon.webp`
    : `${definitionId}.webp`;

  // Check if already exists in storage
  const { data: existingFile } = await supabase.storage
    .from(ART_BUCKET)
    .list("", { search: fileName });

  if (existingFile && existingFile.length > 0) {
    const url = `${supabaseUrl}/storage/v1/object/public/${ART_BUCKET}/${fileName}`;
    console.log(`[art] ${definitionId} ${assetType} already exists`);
    return url;
  }

  const prompt = buildArtPrompt(commonName, scientificName, assetType, enrichment);

  for (let attempt = 0; attempt < ART_MAX_RETRIES; attempt++) {
    try {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_IMAGE_MODEL}:generateContent?key=${geminiKey}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: { responseModalities: ["TEXT", "IMAGE"] },
          }),
        },
      );

      if (response.status === 429) {
        const delayMs = ART_BASE_DELAY_MS * Math.pow(2, attempt);
        console.log(`[art] rate limited for ${definitionId} ${assetType}, backing off ${delayMs}ms (attempt ${attempt + 1}/${ART_MAX_RETRIES})`);
        await new Promise(r => setTimeout(r, delayMs));
        continue;
      }

      if (!response.ok) {
        const errText = await response.text();
        throw new Error(`Gemini API error ${response.status}: ${errText.slice(0, 200)}`);
      }

      const data = await response.json();
      const parts = data.candidates?.[0]?.content?.parts;
      if (!parts) throw new Error("No parts in Gemini response");

      let imageBytes: Uint8Array | null = null;
      for (const part of parts) {
        if (part.inlineData?.mimeType?.startsWith("image/")) {
          const binaryString = atob(part.inlineData.data);
          imageBytes = new Uint8Array(binaryString.length);
          for (let i = 0; i < binaryString.length; i++) {
            imageBytes[i] = binaryString.charCodeAt(i);
          }
          break;
        }
      }
      if (!imageBytes) throw new Error("No image in Gemini response");

      const { error: uploadError } = await supabase.storage
        .from(ART_BUCKET)
        .upload(fileName, imageBytes, { contentType: "image/webp", upsert: true });

      if (uploadError) throw new Error(`Upload failed: ${uploadError.message}`);

      const url = `${supabaseUrl}/storage/v1/object/public/${ART_BUCKET}/${fileName}`;

      // Update enrichment row
      const column = assetType === "icon" ? "icon_url" : "art_url";
      await supabase
        .from("species_enrichment")
        .update({ [column]: url })
        .eq("definition_id", definitionId);

      console.log(`[art] ${assetType} generated for ${definitionId}: ${url}`);
      return url;
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      console.error(`[art] ${assetType} attempt ${attempt + 1} failed for ${definitionId}: ${message}`);
      if (attempt < ART_MAX_RETRIES - 1) {
        const delayMs = ART_BASE_DELAY_MS * Math.pow(2, attempt);
        await new Promise(r => setTimeout(r, delayMs));
      }
    }
  }
  return null;
}

async function fillMissingArt(
  supabase: any,
  supabaseUrl: string,
  definitionId: string,
  scientificName: string,
  commonName: string,
  enrichment: { climate?: string; brawn?: number; wit?: number; speed?: number },
  currentIconUrl: string | null,
  currentArtUrl: string | null,
): Promise<{ icon_url: string | null; art_url: string | null }> {
  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  if (!geminiKey) {
    console.log("[art] GEMINI_API_KEY not set, skipping art generation");
    return { icon_url: currentIconUrl, art_url: currentArtUrl };
  }

  let iconUrl = currentIconUrl;
  let artUrl = currentArtUrl;

  if (!iconUrl) {
    iconUrl = await generateAndUploadArt(
      supabase, supabaseUrl, geminiKey, definitionId, scientificName, commonName, "icon",
    );
  }

  if (!artUrl) {
    artUrl = await generateAndUploadArt(
      supabase, supabaseUrl, geminiKey, definitionId, scientificName, commonName, "illustration", enrichment,
    );
  }

  return { icon_url: iconUrl, art_url: artUrl };
}

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
  icon_url: string | null;
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
  let cleaned = raw.trim();
  const fenceMatch = cleaned.match(/```(?:json)?\s*\n?([\s\S]*?)\n?\s*```/);
  if (fenceMatch) {
    cleaned = fenceMatch[1].trim();
  }
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
  if (!text) throw new Error(`Empty response from ${provider.name}`);

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
  scientificName: string,
  commonName: string,
  taxonomicClass: string,
  validAnimalClasses?: string[],
): Promise<EnrichmentResponse> {
  for (let i = 0; i < providers.length; i++) {
    const provider = providers[i];
    try {
      const result = await callLLM(provider, scientificName, commonName, taxonomicClass, validAnimalClasses);
      console.log(`[enrich] ${scientificName} enriched via ${provider.name} (${provider.model})`);
      return result;
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      console.error(`[enrich] ${provider.name} (${provider.model}) failed for ${scientificName}: ${message}`);
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

    const availableProviders = PROVIDERS.filter(p => Deno.env.get(p.keyEnv));
    if (availableProviders.length === 0) {
      return new Response(
        JSON.stringify({ error: "No AI provider API keys configured" }),
        { status: 503, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
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
      const ex = existing as EnrichmentRow;
      // If art is complete, return as-is
      if (ex.icon_url && ex.art_url) {
        return new Response(JSON.stringify(ex), {
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
      }
      // Art missing — try to generate before returning
      const artResult = await fillMissingArt(
        supabase, supabaseUrl, definition_id, scientific_name, common_name,
        { climate: ex.climate, brawn: ex.brawn, wit: ex.wit, speed: ex.speed },
        ex.icon_url, ex.art_url,
      );
      return new Response(JSON.stringify({ ...ex, ...artResult }), {
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const enrichment = await callLLMWithRotation(availableProviders, scientific_name, common_name, taxonomic_class, sanitizedClasses);

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
      icon_url: existing ? (existing as EnrichmentRow).icon_url : null,
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

    // Generate art for newly enriched species
    const artResult = await fillMissingArt(
      supabase, supabaseUrl, definition_id, scientific_name, common_name,
      { climate: enrichment.climate, brawn: enrichment.brawn, wit: enrichment.wit, speed: enrichment.speed },
      null, null,
    );

    return new Response(JSON.stringify({ ...upserted, ...artResult }), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    const statusCode = err instanceof AllProvidersFailedError ? 502 : ((err as any).statusCode ?? 500);
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
