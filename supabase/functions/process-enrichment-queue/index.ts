import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── Constants ────────────────────────────────────────────────────────────────

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
const ART_MAX_RETRIES = 3;
const ART_BASE_DELAY_MS = 2000;

// ── LLM Providers ────────────────────────────────────────────────────────────

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

// ── Image Generation Providers ──────────────────────────────────────────────

interface ImageResult {
  bytes: Uint8Array;
  mimeType: string; // e.g. "image/png", "image/webp"
}

interface ImageProvider {
  name: string;
  keyEnv: string;
  generate: (
    apiKey: string,
    prompt: string,
  ) => Promise<ImageResult | null>;
  rpmDelay: number; // ms to sleep between calls to respect rate limits
}

const IMAGE_PROVIDERS: ImageProvider[] = [
  {
    name: "gemini",
    keyEnv: "GEMINI_API_KEY",
    rpmDelay: 7000, // 10 RPM → 6s min, use 7s for safety
    generate: async (apiKey: string, prompt: string): Promise<ImageResult | null> => {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=${apiKey}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: { responseModalities: ["TEXT", "IMAGE"] },
          }),
        },
      );

      if (response.status === 429) return null; // rate limited
      if (!response.ok) throw new Error(`Gemini ${response.status}: ${(await response.text()).slice(0, 200)}`);

      const data = await response.json();
      const parts = data.candidates?.[0]?.content?.parts;
      if (!parts) throw new Error("No parts in Gemini response");

      for (const part of parts) {
        if (part.inlineData?.mimeType?.startsWith("image/")) {
          const binaryString = atob(part.inlineData.data);
          const bytes = new Uint8Array(binaryString.length);
          for (let i = 0; i < binaryString.length; i++) {
            bytes[i] = binaryString.charCodeAt(i);
          }
          return { bytes, mimeType: part.inlineData.mimeType };
        }
      }
      throw new Error("No image in Gemini response");
    },
  },
  {
    name: "together-flux",
    keyEnv: "TOGETHER_API_KEY",
    rpmDelay: 2000, // Together AI is more generous
    generate: async (apiKey: string, prompt: string): Promise<ImageResult | null> => {
      const response = await fetch("https://api.together.xyz/v1/images/generations", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "black-forest-labs/FLUX.1-schnell-Free",
          prompt: prompt,
          width: 512,
          height: 512,
          n: 1,
          response_format: "b64_json",
        }),
      });

      if (response.status === 429) return null;
      if (!response.ok) throw new Error(`Together ${response.status}: ${(await response.text()).slice(0, 200)}`);

      const data = await response.json();
      const b64 = data.data?.[0]?.b64_json;
      if (!b64) throw new Error("No image in Together response");

      const binaryString = atob(b64);
      const bytes = new Uint8Array(binaryString.length);
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
      }
      return { bytes, mimeType: "image/webp" };
    },
  },
  {
    name: "leonardo",
    keyEnv: "LEONARDO_API_KEY",
    rpmDelay: 5000, // Conservative for free tier
    generate: async (apiKey: string, prompt: string): Promise<ImageResult | null> => {
      // Leonardo uses async generation: create → poll → download
      const createResponse = await fetch("https://cloud.leonardo.ai/api/rest/v1/generations", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          prompt: prompt,
          width: 512,
          height: 512,
          num_images: 1,
          modelId: "b24e16ff-06e3-43eb-8d33-4416c2d75876", // Leonardo Lightning XL
        }),
      });

      if (createResponse.status === 429) return null;
      if (!createResponse.ok) throw new Error(`Leonardo create ${createResponse.status}: ${(await createResponse.text()).slice(0, 200)}`);

      const createData = await createResponse.json();
      const generationId = createData.sdGenerationJob?.generationId;
      if (!generationId) throw new Error("No generationId from Leonardo");

      // Poll for completion (max 30s)
      for (let i = 0; i < 15; i++) {
        await new Promise(r => setTimeout(r, 2000));
        const pollResponse = await fetch(`https://cloud.leonardo.ai/api/rest/v1/generations/${generationId}`, {
          headers: { "Authorization": `Bearer ${apiKey}` },
        });
        if (!pollResponse.ok) continue;
        const pollData = await pollResponse.json();
        const images = pollData.generations_by_pk?.generated_images;
        if (images && images.length > 0) {
          const imageUrl = images[0].url;
          const imageResponse = await fetch(imageUrl);
          if (!imageResponse.ok) throw new Error(`Failed to download Leonardo image: ${imageResponse.status}`);
          return { bytes: new Uint8Array(await imageResponse.arrayBuffer()), mimeType: "image/webp" };
        }
      }
      throw new Error("Leonardo generation timed out (30s)");
    },
  },
];

// ── Types ─────────────────────────────────────────────────────────────────────

interface EnrichmentResponse {
  animal_class: string;
  food_preference: string;
  climate: string;
  brawn: number;
  wit: number;
  speed: number;
  size: string;
}

interface SpeciesRow {
  definition_id: string;
  scientific_name: string;
  common_name: string;
  taxonomic_class: string;
  animal_class: string | null;
  food_preference: string | null;
  climate: string | null;
  brawn: number | null;
  wit: number | null;
  speed: number | null;
  size: string | null;
  icon_url: string | null;
  art_url: string | null;
  icon_prompt: string | null;
  art_prompt: string | null;
  enriched_at: string | null;
  habitats_json: string | null;
}

// ── Validation ────────────────────────────────────────────────────────────────

function isValidEnrichment(data: unknown): data is EnrichmentResponse {
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
  return true;
}

function extractJSON(raw: string): string {
  let cleaned = raw.trim();
  const fenceMatch = cleaned.match(/```(?:json)?\s*\n?([\s\S]*?)\n?\s*```/);
  if (fenceMatch) cleaned = fenceMatch[1].trim();
  if (cleaned.charCodeAt(0) === 0xFEFF) cleaned = cleaned.slice(1);
  return cleaned;
}

// ── LLM Classification ────────────────────────────────────────────────────────

async function callLLM(
  provider: Provider,
  scientificName: string,
  commonName: string,
  taxonomicClass: string,
): Promise<EnrichmentResponse> {
  const apiKey = Deno.env.get(provider.keyEnv);
  if (!apiKey) throw new Error(`${provider.name} API key not set (${provider.keyEnv})`);

  const prompt = `You are a wildlife classification expert. Given this species, return a JSON object with EXACTLY these fields:
- animal_class: one of [${ANIMAL_CLASSES.join(", ")}]
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

  const response = await fetch(provider.url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: provider.model,
      messages: [
        { role: "system", content: "You are a wildlife classification expert. Always respond with valid JSON only, no markdown fences." },
        { role: "user", content: prompt },
      ],
      temperature: 0.3,
      response_format: { type: "json_object" },
    }),
  });

  if (!response.ok) {
    const errBody = await response.text();
    const err = new Error(`${provider.name} API error ${response.status}: ${errBody}`);
    (err as any).statusCode = response.status;
    if (response.status === 429) (err as any).retryAfter = response.headers.get("retry-after") ?? "60";
    throw err;
  }

  const body = await response.json();
  const text = body?.choices?.[0]?.message?.content;
  if (!text) throw new Error(`Empty response from ${provider.name}`);

  const parsed = JSON.parse(extractJSON(text));
  if (!isValidEnrichment(parsed)) {
    throw new Error(`Invalid enrichment from ${provider.name} for ${taxonomicClass}: ${JSON.stringify(parsed)}`);
  }
  return parsed;
}

async function callLLMWithRotation(
  providers: Provider[],
  scientificName: string,
  commonName: string,
  taxonomicClass: string,
): Promise<{ result: EnrichmentResponse; providerName: string }> {
  for (const provider of providers) {
    try {
      const result = await callLLM(provider, scientificName, commonName, taxonomicClass);
      console.log(`[classify] ${scientificName} classified via ${provider.name} (${provider.model})`);
      return { result, providerName: provider.name };
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      console.error(`[classify] ${provider.name} failed for ${scientificName}: ${message}`);
    }
  }
  throw new Error(`All ${providers.length} providers failed for ${scientificName}`);
}

// ── Art Generation ────────────────────────────────────────────────────────────

function parseFirstHabitat(json: string | null | undefined): string | null {
  if (!json) return null;
  try {
    const arr = JSON.parse(json);
    return Array.isArray(arr) && arr.length > 0 ? String(arr[0]).toLowerCase() : null;
  } catch { return null; }
}

// ── 2-Stage Art Prompt Pipeline ──────────────────────────────────────────────
//
// Stage 1: LLM text call generates a species-specific image prompt using
//          enrichment data (stats, habitat, food preference, etc.)
// Stage 2: Image model generates the image from that prompt.
//
// The generated prompt is stored on the species row (icon_prompt / art_prompt)
// so we can inspect, iterate, and regenerate selectively.

const ICON_META_PROMPT = `You are writing an image generation prompt for a game creature icon.

ART DIRECTION:
- 32×32 pixel art sprite. Pokémon PC box style.
- Flat fill colors only — NO gradients, NO 3D shading, NO highlights, NO specular reflections, NO rim lighting.
- Bold clean outlines, 4-6 colors from the animal's real palette.
- Chibi proportions: oversized head (~50% of body), stubby limbs, big round eyes.
- Front-facing, whole body visible, grounded at bottom of frame.
- Must be instantly recognizable as this species at 32px.

YOUR JOB:
Given the species data below, write a short image prompt that captures
the 1-2 visual features that make THIS species recognizable at a glance.
Be specific — don't say "distinctive markings," say "black mask across
eyes" or "bright red throat pouch." Think about what a child would draw
if asked to draw this animal.

OUTPUT:
Write ONLY the image prompt (2-4 sentences). No preamble, no explanation.
Always end with: "Flat cartoon lighting. Transparent PNG background. No ground, no shadow, no effects."`;

const CARD_ART_META_PROMPT = `You are writing an image generation prompt for a collectible creature card illustration (512×512).

ART DIRECTION:
- Watercolor illustration with soft edges and gentle color bleeding.
- Cute, rounded, slightly exaggerated proportions — NOT realistic anatomy.
- Think PuffPals, Ooblets, Slime Rancher — cozy game creature art.
- The animal should feel friendly and appealing even if the real species is scary (e.g., a cute chunky crocodile, a friendly round spider).
- Warm natural habitat background, loosely painted, soft focus.
- Gentle lighting — no dramatic shadows, no harsh contrast.

YOUR JOB:
Given the species data below, write a vivid image prompt that:
1. Describes the animal with 2-3 specific visual details (coloring, pattern, distinctive body features).
2. Reflects the dominant stat in body language and build:
   - brawn → sturdy, grounded, powerful presence, thick limbs
   - speed → mid-motion, dynamic angle, lean and agile
   - wit → alert eyes, clever expression, observant pose
3. Shows the animal in an EXCITING, DYNAMIC moment — the shot that would make the best trading card. Pick a dramatic angle:
   - Leaping toward the viewer, foreshortened
   - Diving from above, wings/limbs spread wide
   - Bursting through foliage or water
   - Rearing up, silhouetted against sky
   - Charging forward with dust/snow/water kicked up
   - Soaring low over terrain, speed lines implied
   The action should be ICONIC for this species — the thing it's famous for. A puma mid-leap across a canyon. A peregrine falcon in a vertical dive. A bison charging through dust. An otter cracking a shell on its chest. A chameleon's tongue mid-strike.
   For slow/calm animals, make the COMPOSITION dramatic instead — a tortoise framed heroically from below against golden sky, a sloth hanging serenely with jungle sprawling behind it.
   Camera angle should feel cinematic — low angle, dramatic 3/4 view, dynamic diagonal composition. Never flat, never centered, never static portrait.
4. Places it in a loosely-painted habitat setting that matches its biome.
5. Uses size to set scale — large animals dominate the frame, small animals are perched on mushrooms/branches/rocks.

OUTPUT:
Write ONLY the image prompt (3-5 sentences). No preamble, no explanation.
Always end with: "Watercolor illustration, soft edges, cozy game art style. No text, no border, no frame."`;

function buildSpeciesDataBlock(species: SpeciesRow, habitat: string | null): string {
  let dominantStat = "balanced";
  if (species.brawn != null && species.wit != null && species.speed != null) {
    const max = Math.max(species.brawn, species.wit, species.speed);
    if (species.brawn === max) dominantStat = "brawn";
    else if (species.speed === max) dominantStat = "speed";
    else dominantStat = "wit";
  }

  return `
- Common name: ${species.common_name}
- Scientific name: ${species.scientific_name}
- Animal class: ${species.animal_class ?? "unknown"}
- Habitat: ${habitat ?? "unknown"}
- Size: ${species.size ?? "unknown"}
- Climate: ${species.climate ?? "unknown"}
- Dominant stat: ${dominantStat}
- Food preference: ${species.food_preference ?? "unknown"}`;
}

async function generateArtPrompt(
  providers: Provider[],
  species: SpeciesRow,
  assetType: "icon" | "illustration",
  habitat: string | null,
): Promise<string> {
  const metaPrompt = assetType === "icon" ? ICON_META_PROMPT : CARD_ART_META_PROMPT;
  const speciesData = buildSpeciesDataBlock(species, habitat);
  const userMessage = `${metaPrompt}\n\nSPECIES DATA:\n${speciesData}`;

  for (const provider of providers) {
    const apiKey = Deno.env.get(provider.keyEnv);
    if (!apiKey) continue;

    try {
      const response = await fetch(provider.url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: provider.model,
          messages: [
            { role: "system", content: "You write concise, vivid image generation prompts. Output ONLY the prompt text, nothing else." },
            { role: "user", content: userMessage },
          ],
          temperature: 0.7,
        }),
      });

      if (!response.ok) {
        console.error(`[prompt] ${provider.name} failed: ${response.status}`);
        continue;
      }

      const body = await response.json();
      const text = body?.choices?.[0]?.message?.content?.trim();
      if (text && text.length > 20) {
        console.log(`[prompt] ${assetType} prompt generated via ${provider.name} (${text.length} chars)`);
        return text;
      }
    } catch (err) {
      console.error(`[prompt] ${provider.name} error: ${err instanceof Error ? err.message : String(err)}`);
    }
  }
  throw new Error(`All providers failed to generate ${assetType} prompt for ${species.definition_id}`);
}

// Rotates through IMAGE_PROVIDERS; returns { url, provider } on success,
// "rate_limited" if all providers are exhausted/rate-limited, null on total failure.
// Takes a pre-generated prompt from the 2-stage pipeline.
async function generateAndUploadArt(
  supabase: any,
  supabaseUrl: string,
  definitionId: string,
  assetType: "icon" | "illustration",
  prompt: string,
  logEvent?: (type: string, defId: string | null, extra: Record<string, unknown>) => Promise<void>,
): Promise<{ url: string; provider: string } | "rate_limited" | null> {
  const filePrefix = assetType === "icon" ? `${definitionId}_icon` : definitionId;

  // Try each image provider in order
  const availableProviders = IMAGE_PROVIDERS.filter(p => Deno.env.get(p.keyEnv));

  for (const provider of availableProviders) {
    const apiKey = Deno.env.get(provider.keyEnv)!;
    const startMs = Date.now();

    for (let attempt = 0; attempt < ART_MAX_RETRIES; attempt++) {
      try {
        const imageResult = await provider.generate(apiKey, prompt);

        if (imageResult === null) {
          // Rate limited — try next provider
          console.log(`[art] ${provider.name} rate limited for ${definitionId} ${assetType}`);
          if (logEvent) await logEvent('rate_limited', definitionId, { asset_type: assetType, provider_name: provider.name });
          break; // break retry loop, continue to next provider
        }

        // Upload to storage with the provider's actual mime type.
        // Icons from Gemini may be PNG (with alpha); illustrations are typically WebP.
        const ext = imageResult.mimeType === "image/png" ? "png" : "webp";
        const actualFileName = assetType === "icon"
          ? `${definitionId}_icon.${ext}`
          : `${definitionId}.${ext}`;
        const { error: uploadError } = await supabase.storage
          .from(ART_BUCKET)
          .upload(actualFileName, imageResult.bytes, { contentType: imageResult.mimeType, upsert: true });

        if (uploadError) throw new Error(`Upload failed: ${uploadError.message}`);

        const url = `${supabaseUrl}/storage/v1/object/public/${ART_BUCKET}/${actualFileName}`;
        const durationMs = Date.now() - startMs;

        // Update species row — bump enriched_at so client delta-sync picks up art changes
        const column = assetType === "icon" ? "icon_url" : "art_url";
        await supabase.from("species").update({ [column]: url, enriched_at: new Date().toISOString() }).eq("definition_id", definitionId);

        console.log(`[art] ${assetType} generated for ${definitionId} via ${provider.name}: ${url}`);
        if (logEvent) await logEvent('art_success', definitionId, { asset_type: assetType, provider_name: provider.name, duration_ms: durationMs });

        // Sleep to respect rate limits
        await new Promise(r => setTimeout(r, provider.rpmDelay));

        return { url, provider: provider.name };
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        console.error(`[art] ${provider.name} attempt ${attempt + 1} failed for ${definitionId} ${assetType}: ${message}`);

        if (attempt < ART_MAX_RETRIES - 1) {
          const delayMs = ART_BASE_DELAY_MS * Math.pow(2, attempt);
          await new Promise(r => setTimeout(r, delayMs));
        } else {
          if (logEvent) await logEvent('art_error', definitionId, { asset_type: assetType, provider_name: provider.name, error_message: message, duration_ms: Date.now() - startMs });
        }
      }
    }
  }

  // All providers exhausted
  return "rate_limited";
}

// ── Main Handler ──────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  const workerStartMs = Date.now();

  // Auth: accept service role key only (called by pg_cron, not users)
  const authHeader = req.headers.get("authorization");
  if (authHeader) {
    const token = authHeader.replace("Bearer ", "");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (serviceKey && token !== serviceKey) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceKey);

  // -- Observability helper --------------------------------------------------
  async function logEvent(
    eventType: string,
    definitionId: string | null,
    extra: Record<string, unknown> = {},
  ) {
    try {
      await supabase.from('enrichment_events').insert({
        event_type: eventType,
        definition_id: definitionId,
        provider_name: extra.provider_name ?? null,
        asset_type: extra.asset_type ?? null,
        duration_ms: extra.duration_ms ?? null,
        error_message: extra.error_message ?? null,
        metadata: extra.metadata ?? null,
      });
    } catch (e) {
      // Don't let logging failures break the pipeline
      console.error(`[log] failed to write event: ${e}`);
    }
  }

  const errors: string[] = [];
  let classified = 0;
  let icons = 0;
  let illustrations = 0;

  // ── Pass 1: Classify ONE species ────────────────────────────────────────
  //
  // Process a single species per invocation to stay within the free-tier
  // Edge Function resource limits (2s CPU, 256MB memory). The pg_cron job
  // runs hourly; increase frequency for faster backfill.

  try {
    const availableProviders = PROVIDERS.filter(p => Deno.env.get(p.keyEnv));
    if (availableProviders.length === 0) {
      errors.push("Pass 1 skipped: no AI provider API keys configured");
    } else {
      // Find one discovered species that needs classification.
      // Uses an RPC call to avoid fetching 10K item_instances rows.
      const { data: needsClassification, error: speciesErr } = await supabase
        .from("species")
        .select("definition_id, scientific_name, common_name, taxonomic_class")
        .is("animal_class", null)
        .limit(1)
        .maybeSingle();

      if (speciesErr) throw new Error(`Failed to query species: ${speciesErr.message}`);

      if (!needsClassification) {
        console.log('[pass1] nothing to classify');
      } else {
        const species = needsClassification as SpeciesRow;
        const startMs = Date.now();
        try {
          const { result: enrichment, providerName } = await callLLMWithRotation(
            availableProviders,
            species.scientific_name,
            species.common_name,
            species.taxonomic_class,
          );
          const durationMs = Date.now() - startMs;

          const { error: updateErr } = await supabase
            .from("species")
            .update({
              animal_class: enrichment.animal_class,
              food_preference: enrichment.food_preference,
              climate: enrichment.climate,
              brawn: enrichment.brawn,
              wit: enrichment.wit,
              speed: enrichment.speed,
              size: enrichment.size,
              enriched_at: new Date().toISOString(),
            })
            .eq("definition_id", species.definition_id);

          if (updateErr) throw new Error(`UPDATE failed for ${species.definition_id}: ${updateErr.message}`);

          classified++;
          console.log(`[pass1] classified ${species.scientific_name} → ${enrichment.animal_class}`);
          await logEvent('classification_success', species.definition_id, {
            provider_name: providerName,
            duration_ms: durationMs,
          });
        } catch (err) {
          const message = err instanceof Error ? err.message : String(err);
          errors.push(`Pass 1 classify ${species.definition_id}: ${message}`);
          console.error(`[pass1] error for ${species.definition_id}: ${message}`);
          await logEvent('classification_error', species.definition_id, {
            error_message: message,
            duration_ms: Date.now() - startMs,
          });
        }
      }
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    errors.push(`Pass 1 fatal: ${message}`);
    console.error(`[pass1] fatal: ${message}`);
  }

  // ── Pass 2: Generate art for ONE species ──────────────────────────────

  try {
    const availableImageProviders = IMAGE_PROVIDERS.filter(p => Deno.env.get(p.keyEnv));
    if (availableImageProviders.length === 0) {
      errors.push("Pass 2 skipped: no image provider API keys configured");
    } else {
      // 2-Stage art pipeline: LLM generates prompt → image model generates art.
      // Prioritize species closest to complete.
      const artColumns = "definition_id, scientific_name, common_name, taxonomic_class, animal_class, food_preference, climate, brawn, wit, speed, size, icon_url, art_url, icon_prompt, art_prompt, enriched_at, habitats_json";
      const availableLLMProviders = PROVIDERS.filter(p => Deno.env.get(p.keyEnv));

      // Priority 1: has icon, missing art only (one step from complete)
      const { data: needsArtOnly, error: artOnlyErr } = await supabase
        .from("species")
        .select(artColumns)
        .not("animal_class", "is", null)
        .not("icon_url", "is", null)
        .is("art_url", null)
        .order("enriched_at", { ascending: true })
        .limit(1)
        .maybeSingle();
      if (artOnlyErr) throw new Error(`Failed to query species (art-only): ${artOnlyErr.message}`);

      // Priority 2: needs icon (and possibly art too)
      const needsArt = needsArtOnly ?? await (async () => {
        const { data, error } = await supabase
          .from("species")
          .select(artColumns)
          .not("animal_class", "is", null)
          .is("icon_url", null)
          .order("enriched_at", { ascending: true })
          .limit(1)
          .maybeSingle();
        if (error) throw new Error(`Failed to query species (needs-icon): ${error.message}`);
        return data;
      })();

      if (!needsArt) {
        console.log('[pass2] nothing to generate');
      } else {
        const priority = needsArtOnly ? 'art-only' : 'needs-icon';
        console.log(`[pass2] picked ${needsArt.definition_id} (${priority})`);
        const species = needsArt as SpeciesRow;
        const habitat = parseFirstHabitat(species.habitats_json);

        // ── Stage 1: Generate prompts via LLM (if not already cached) ────
        let iconPrompt = species.icon_prompt;
        let artPrompt = species.art_prompt;

        if (!iconPrompt && !species.icon_url && availableLLMProviders.length > 0) {
          try {
            iconPrompt = await generateArtPrompt(availableLLMProviders, species, "icon", habitat);
            await supabase.from("species").update({ icon_prompt: iconPrompt }).eq("definition_id", species.definition_id);
          } catch (err) {
            const msg = err instanceof Error ? err.message : String(err);
            errors.push(`Stage 1 icon prompt: ${msg}`);
            console.error(`[pass2] icon prompt failed: ${msg}`);
          }
        }

        if (!artPrompt && !species.art_url && availableLLMProviders.length > 0) {
          try {
            artPrompt = await generateArtPrompt(availableLLMProviders, species, "illustration", habitat);
            await supabase.from("species").update({ art_prompt: artPrompt }).eq("definition_id", species.definition_id);
          } catch (err) {
            const msg = err instanceof Error ? err.message : String(err);
            errors.push(`Stage 1 art prompt: ${msg}`);
            console.error(`[pass2] art prompt failed: ${msg}`);
          }
        }

        // ── Stage 2: Generate images from prompts ────────────────────────
        if (!species.icon_url && iconPrompt) {
          const result = await generateAndUploadArt(
            supabase, supabaseUrl,
            species.definition_id, "icon", iconPrompt, logEvent,
          );
          if (result === "rate_limited") {
            errors.push("Pass 2 stopped: all image providers rate limited");
          } else if (result) {
            icons++;
          }
        }

        if (!species.art_url && artPrompt) {
          const result = await generateAndUploadArt(
            supabase, supabaseUrl,
            species.definition_id, "illustration", artPrompt, logEvent,
          );
          if (result === "rate_limited") {
            errors.push("Pass 2 stopped: all image providers rate limited");
          } else if (result) {
            illustrations++;
          }
        }
      }
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    errors.push(`Pass 2 fatal: ${message}`);
    console.error(`[pass2] fatal: ${message}`);
  }

  const result = { classified, icons, illustrations, errors };
  console.log(`[worker] done — classified=${classified} icons=${icons} illustrations=${illustrations} errors=${errors.length}`);

  // Query remaining queue depth for the summary
  let pendingClassification = 0;
  let pendingArt = 0;
  try {
    const { count: classCount } = await supabase
      .from('species')
      .select('definition_id', { count: 'exact', head: true })
      .is('animal_class', null);
    const { count: artCount } = await supabase
      .from('species')
      .select('definition_id', { count: 'exact', head: true })
      .not('animal_class', 'is', null)
      .or('icon_url.is.null,art_url.is.null');
    pendingClassification = classCount ?? 0;
    pendingArt = artCount ?? 0;
  } catch (_) { /* non-critical */ }

  await logEvent('worker_run', null, {
    metadata: {
      classified,
      icons,
      illustrations,
      errors: errors.length,
      pending_classification: pendingClassification,
      pending_art: pendingArt,
    },
    duration_ms: Date.now() - workerStartMs,
  });

  return new Response(JSON.stringify(result), {
    headers: { "Content-Type": "application/json" },
  });
});
