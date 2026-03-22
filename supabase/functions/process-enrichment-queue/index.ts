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

// Concurrency limits — prevent rate limit storms from parallel calls.
const MAX_LLM_CONCURRENT = 5;   // prompt generation + classification
const MAX_IMAGE_CONCURRENT = 2; // image generation (slowest, most expensive)

/** Run async task factories with a concurrency limit. */
async function pooled(tasks: (() => Promise<void>)[], limit: number): Promise<void> {
  let i = 0;
  async function worker(): Promise<void> {
    while (i < tasks.length) {
      const idx = i++;
      await tasks[idx]();
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, tasks.length) }, () => worker()));
}

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
  // enrichver fields
  animal_class_enrichver: string | null;
  food_preference_enrichver: string | null;
  climate_enrichver: string | null;
  brawn_enrichver: string | null;
  wit_enrichver: string | null;
  speed_enrichver: string | null;
  size_enrichver: string | null;
  icon_prompt_enrichver: string | null;
  art_prompt_enrichver: string | null;
  icon_url_enrichver: string | null;
  art_url_enrichver: string | null;
}

// ── Species enrichment stage selection ───────────────────────────────────────

type SpeciesStage =
  | "classify"
  | "icon_prompt"
  | "art_prompt"
  | "icon_url"
  | "art_url"
  | null;

function speciesFieldsNeedingWork(row: SpeciesRow, pipelineVersion: string): number {
  let count = 0;
  if (row.animal_class === null || row.animal_class_enrichver !== pipelineVersion) count++;
  if (row.icon_prompt === null || row.icon_prompt_enrichver !== pipelineVersion) count++;
  if (row.art_prompt === null || row.art_prompt_enrichver !== pipelineVersion) count++;
  if (row.icon_url === null || row.icon_url_enrichver !== pipelineVersion) count++;
  if (row.art_url === null || row.art_url_enrichver !== pipelineVersion) count++;
  return count;
}

function nextSpeciesStage(row: SpeciesRow, pipelineVersion: string): SpeciesStage {
  if (row.animal_class === null || row.animal_class_enrichver !== pipelineVersion) return "classify";
  if (row.icon_prompt === null || row.icon_prompt_enrichver !== pipelineVersion) return "icon_prompt";
  if (row.art_prompt === null || row.art_prompt_enrichver !== pipelineVersion) return "art_prompt";
  if (row.icon_url === null || row.icon_url_enrichver !== pipelineVersion) return "icon_url";
  if (row.art_url === null || row.art_url_enrichver !== pipelineVersion) return "art_url";
  return null;
}

// ── Item instance enrichment score ───────────────────────────────────────────

interface ItemInstanceRow {
  id: string;
  definition_id: string;
  acquired_in_cell_id: string | null;
  animal_class_name: string | null;
  animal_class_name_enrichver: string | null;
  food_preference_name: string | null;
  food_preference_name_enrichver: string | null;
  climate_name: string | null;
  climate_name_enrichver: string | null;
  brawn: number | null;
  brawn_enrichver: string | null;
  wit: number | null;
  wit_enrichver: string | null;
  speed: number | null;
  speed_enrichver: string | null;
  size_name: string | null;
  size_name_enrichver: string | null;
  icon_url: string | null;
  icon_url_enrichver: string | null;
  art_url: string | null;
  art_url_enrichver: string | null;
  cell_habitat_name: string | null;
  cell_habitat_name_enrichver: string | null;
  cell_climate_name: string | null;
  cell_climate_name_enrichver: string | null;
  cell_continent_name: string | null;
  cell_continent_name_enrichver: string | null;
  location_district: string | null;
  location_district_enrichver: string | null;
  location_city: string | null;
  location_city_enrichver: string | null;
  location_state: string | null;
  location_state_enrichver: string | null;
  location_country: string | null;
  location_country_enrichver: string | null;
  location_country_code: string | null;
  location_country_code_enrichver: string | null;
}

function itemFieldsNeedingWork(row: ItemInstanceRow, pipelineVersion: string): number {
  let count = 0;
  if (row.animal_class_name === null || row.animal_class_name_enrichver !== pipelineVersion) count++;
  if (row.icon_url === null || row.icon_url_enrichver !== pipelineVersion) count++;
  if (row.art_url === null || row.art_url_enrichver !== pipelineVersion) count++;
  if (row.cell_habitat_name === null || row.cell_habitat_name_enrichver !== pipelineVersion) count++;
  if (row.location_city === null || row.location_city_enrichver !== pipelineVersion) count++;
  return count;
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
1. Describes the animal with 2-3 specific visual details (coloring,
   pattern, distinctive body features).
2. Shows the animal doing the ONE THING it is most famous for — the
   behavior a nature documentary would feature. Use your real-world
   knowledge of this species. Every species has an iconic behavior.
   Find it. DO NOT default to generic actions like "sprinting" or
   "hunting." Examples of iconic behaviors:
   - An anole flashing its bright dewlap
   - A hummingbird hovering at a flower
   - A pangolin curled into an armored ball
   - A pistol shrimp snapping its claw
   - A chameleon's tongue mid-strike at an insect
   - An archerfish spitting water at a bug
3. The dominant stat FLAVORS how the iconic action is depicted. Same
   action, different energy:
   - brawn → the powerful version. An anole flashing its dewlap while
     puffed up huge, dominating the branch, muscles tense. A bison
     stampeding — massive, unstoppable, dust exploding.
   - speed → the fast version. An anole mid-leap between branches,
     dewlap flashing as it lands. A chameleon tongue mid-strike,
     frozen at the instant of peak velocity.
   - wit → the clever version. An anole strategically positioned on
     the highest branch, dewlap angled to catch a rival's eye. An
     archerfish calculating the perfect angle before spitting.
   The stat doesn't change WHAT the animal does — it changes HOW
   it does it.
4. Camera angle should feel cinematic and exciting — low angle, dramatic
   3/4 view, dynamic diagonal composition. Never flat, never centered,
   never a static portrait. The shot that would make the best trading card.
5. Places it in a loosely-painted habitat setting that matches its biome.
6. Uses size to set scale — large animals dominate the frame, small animals
   are perched on mushrooms/branches/rocks.

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
  pipelineVersion: string,
  logEvent?: (type: string, defId: string | null, extra: Record<string, unknown>) => Promise<void>,
): Promise<{ url: string; provider: string } | "rate_limited" | null> {
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

        // Post-process icons: remove background for true transparency.
        // AI image generators cannot produce real alpha channels — they draw
        // fake checkerboard or solid backgrounds. We use remove.bg API to
        // strip the background and get a clean transparent PNG.
        let finalBytes = imageResult.bytes;
        let finalMimeType = imageResult.mimeType;

        if (assetType === "icon") {
          const removeBgKey = Deno.env.get("REMOVE_BG_API_KEY");
          if (removeBgKey) {
            try {
              const formData = new FormData();
              formData.append("image_file", new Blob([imageResult.bytes], { type: imageResult.mimeType }), "icon.png");
              formData.append("size", "auto");

              const bgResponse = await fetch("https://api.remove.bg/v1.0/removebg", {
                method: "POST",
                headers: { "X-Api-Key": removeBgKey },
                body: formData,
              });

              if (bgResponse.ok) {
                finalBytes = new Uint8Array(await bgResponse.arrayBuffer());
                finalMimeType = "image/png";
                console.log(`[art] background removed for ${definitionId} icon (${finalBytes.length} bytes)`);
              } else {
                const errorText = await bgResponse.text();
                console.error(`[art] remove.bg failed (${bgResponse.status}): ${errorText}`);
                // Continue with original image — background removal is best-effort
              }
            } catch (bgErr) {
              console.error(`[art] remove.bg error: ${bgErr instanceof Error ? bgErr.message : String(bgErr)}`);
              // Continue with original image
            }
          }
        }

        // Upload to storage
        const ext = finalMimeType === "image/png" ? "png" : "webp";
        const actualFileName = assetType === "icon"
          ? `${definitionId}_icon.${ext}`
          : `${definitionId}.${ext}`;
        const { error: uploadError } = await supabase.storage
          .from(ART_BUCKET)
          .upload(actualFileName, finalBytes, { contentType: finalMimeType, upsert: true });

        if (uploadError) throw new Error(`Upload failed: ${uploadError.message}`);

        const url = `${supabaseUrl}/storage/v1/object/public/${ART_BUCKET}/${actualFileName}`;
        const durationMs = Date.now() - startMs;

        // Update species row with url + enrichver
        const column = assetType === "icon" ? "icon_url" : "art_url";
        const enrichverColumn = assetType === "icon" ? "icon_url_enrichver" : "art_url_enrichver";
        await supabase.from("species").update({
          [column]: url,
          [enrichverColumn]: pipelineVersion,
          enriched_at: new Date().toISOString(),
        }).eq("definition_id", definitionId);

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
  const pipelineVersion = Deno.env.get("PIPELINE_VERSION") ?? "unknown";
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
  let speciesEnriched = 0;
  let itemStage: string | null = null;
  let itemsEnriched = 0;

  // ── Species enrichment ────────────────────────────────────────────────────
  //
  // For each species with work to do: check which stages have deps already
  // met, fire them all in parallel. No loops, no sequential layer awaits.
  //
  // Dependency graph:
  //   classify (no deps)
  //     ├→ icon_prompt (needs animal_class) ─→ icon_url (needs icon_prompt)
  //     └→ art_prompt  (needs animal_class) ─→ art_url  (needs art_prompt)
  //
  // Rate limits: LLM calls are cheap (batch many). Image generation is
  // expensive (cap at 3 per tick to respect API rate limits).

  try {
    const availableProviders = PROVIDERS.filter(p => Deno.env.get(p.keyEnv));
    const availableImageProviders = IMAGE_PROVIDERS.filter(p => Deno.env.get(p.keyEnv));

    const speciesColumns = [
      "definition_id", "scientific_name", "common_name", "taxonomic_class",
      "animal_class", "food_preference", "climate", "brawn", "wit", "speed", "size",
      "icon_url", "art_url", "icon_prompt", "art_prompt", "enriched_at", "habitats_json",
      "animal_class_enrichver", "food_preference_enrichver", "climate_enrichver",
      "brawn_enrichver", "wit_enrichver", "speed_enrichver", "size_enrichver",
      "icon_prompt_enrichver", "art_prompt_enrichver", "icon_url_enrichver", "art_url_enrichver",
    ].join(", ");

    const { data: candidates, error: candidatesErr } = await supabase
      .from("species")
      .select(speciesColumns)
      .or([
        `animal_class.is.null`,
        `animal_class_enrichver.is.null`,
        `animal_class_enrichver.neq.${pipelineVersion}`,
        `icon_prompt.is.null`,
        `icon_prompt_enrichver.is.null`,
        `icon_prompt_enrichver.neq.${pipelineVersion}`,
        `art_prompt.is.null`,
        `art_prompt_enrichver.is.null`,
        `art_prompt_enrichver.neq.${pipelineVersion}`,
        `icon_url.is.null`,
        `icon_url_enrichver.is.null`,
        `icon_url_enrichver.neq.${pipelineVersion}`,
        `art_url.is.null`,
        `art_url_enrichver.is.null`,
        `art_url_enrichver.neq.${pipelineVersion}`,
      ].join(","))
      .limit(100);

    if (candidatesErr) throw new Error(`Failed to query species candidates: ${candidatesErr.message}`);

    if (!candidates || candidates.length === 0) {
      console.log('[species] nothing to enrich');
    } else {
      // Score and sort: fewest fields needing work first
      const scored = (candidates as SpeciesRow[]).map(row => ({
        row,
        score: speciesFieldsNeedingWork(row, pipelineVersion),
      }));
      scored.sort((a, b) => a.score - b.score);

      const needs = (val: unknown, ver: string | null) =>
        val === null || val === undefined || ver !== pipelineVersion;

      // Collect task factories (not executing yet) by type for pooled execution
      const llmTasks: (() => Promise<void>)[] = [];
      const imageTasks: (() => Promise<void>)[] = [];
      const allStages: string[] = [];

      for (const { row: species } of scored) {
        const defId = species.definition_id;

        // classify — no deps (LLM call)
        if (needs(species.animal_class, species.animal_class_enrichver) && availableProviders.length > 0) {
          allStages.push(`${defId}:classify`);
          llmTasks.push(async () => {
            const startMs = Date.now();
            try {
              const { result: enrichment, providerName } = await callLLMWithRotation(
                availableProviders, species.scientific_name, species.common_name, species.taxonomic_class,
              );
              const { error } = await supabase.from("species").update({
                animal_class: enrichment.animal_class, animal_class_enrichver: pipelineVersion,
                food_preference: enrichment.food_preference, food_preference_enrichver: pipelineVersion,
                climate: enrichment.climate, climate_enrichver: pipelineVersion,
                brawn: enrichment.brawn, brawn_enrichver: pipelineVersion,
                wit: enrichment.wit, wit_enrichver: pipelineVersion,
                speed: enrichment.speed, speed_enrichver: pipelineVersion,
                size: enrichment.size, size_enrichver: pipelineVersion,
                enriched_at: new Date().toISOString(),
              }).eq("definition_id", defId);
              if (error) throw new Error(`UPDATE failed: ${error.message}`);
              speciesEnriched++;
              await logEvent('classification_success', defId, { provider_name: providerName, duration_ms: Date.now() - startMs });
            } catch (err) {
              errors.push(`${defId} classify: ${err instanceof Error ? err.message : String(err)}`);
            }
          });
        }

        // icon_prompt — needs animal_class to ALREADY EXIST (LLM call)
        if (species.animal_class && needs(species.icon_prompt, species.icon_prompt_enrichver) && availableProviders.length > 0) {
          allStages.push(`${defId}:icon_prompt`);
          const habitat = parseFirstHabitat(species.habitats_json);
          llmTasks.push(async () => {
            try {
              const prompt = await generateArtPrompt(availableProviders, species, "icon", habitat);
              const { error } = await supabase.from("species")
                .update({ icon_prompt: prompt, icon_prompt_enrichver: pipelineVersion })
                .eq("definition_id", defId);
              if (error) throw new Error(`UPDATE icon_prompt failed: ${error.message}`);
              speciesEnriched++;
            } catch (err) {
              errors.push(`${defId} icon_prompt: ${err instanceof Error ? err.message : String(err)}`);
            }
          });
        }

        // art_prompt — needs animal_class to ALREADY EXIST (LLM call)
        if (species.animal_class && needs(species.art_prompt, species.art_prompt_enrichver) && availableProviders.length > 0) {
          allStages.push(`${defId}:art_prompt`);
          const habitat = parseFirstHabitat(species.habitats_json);
          llmTasks.push(async () => {
            try {
              const prompt = await generateArtPrompt(availableProviders, species, "illustration", habitat);
              const { error } = await supabase.from("species")
                .update({ art_prompt: prompt, art_prompt_enrichver: pipelineVersion })
                .eq("definition_id", defId);
              if (error) throw new Error(`UPDATE art_prompt failed: ${error.message}`);
              speciesEnriched++;
            } catch (err) {
              errors.push(`${defId} art_prompt: ${err instanceof Error ? err.message : String(err)}`);
            }
          });
        }

        // icon_url — needs icon_prompt to ALREADY EXIST (image API call)
        if (species.icon_prompt && needs(species.icon_url, species.icon_url_enrichver) && availableImageProviders.length > 0) {
          allStages.push(`${defId}:icon_url`);
          imageTasks.push(async () => {
            try {
              const result = await generateAndUploadArt(
                supabase, supabaseUrl, defId, "icon", species.icon_prompt!, pipelineVersion, logEvent,
              );
              if (result === "rate_limited") { errors.push(`icon_url: rate limited for ${defId}`); return; }
              if (result) speciesEnriched++;
            } catch (err) {
              errors.push(`${defId} icon_url: ${err instanceof Error ? err.message : String(err)}`);
            }
          });
        }

        // art_url — needs art_prompt to ALREADY EXIST (image API call)
        if (species.art_prompt && needs(species.art_url, species.art_url_enrichver) && availableImageProviders.length > 0) {
          allStages.push(`${defId}:art_url`);
          imageTasks.push(async () => {
            try {
              const result = await generateAndUploadArt(
                supabase, supabaseUrl, defId, "illustration", species.art_prompt!, pipelineVersion, logEvent,
              );
              if (result === "rate_limited") { errors.push(`art_url: rate limited for ${defId}`); return; }
              if (result) speciesEnriched++;
            } catch (err) {
              errors.push(`${defId} art_url: ${err instanceof Error ? err.message : String(err)}`);
            }
          });
        }
      }

      console.log(`[species] queued ${llmTasks.length} LLM + ${imageTasks.length} image tasks across ${scored.length} candidates`);

      // Run LLM and image pools concurrently, each with their own limit
      await Promise.all([
        llmTasks.length > 0 ? pooled(llmTasks, MAX_LLM_CONCURRENT) : Promise.resolve(),
        imageTasks.length > 0 ? pooled(imageTasks, MAX_IMAGE_CONCURRENT) : Promise.resolve(),
      ]);

      itemStage = `${allStages.length} stages`;
      console.log(`[species] done — ${speciesEnriched} enriched, ${errors.length} errors`);
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    errors.push(`Species enrichment fatal: ${message}`);
    console.error(`[species] fatal: ${message}`);
  }

  // ── Item denormalization: batch of up to 50 ───────────────────────────────
  //
  // Pure SQL look-ups — no API calls. Fill whatever is available from already-
  // enriched species rows and cell_properties.

  try {
    const itemColumns = [
      "id", "definition_id", "acquired_in_cell_id",
      "animal_class_name", "animal_class_name_enrichver",
      "food_preference_name", "food_preference_name_enrichver",
      "climate_name", "climate_name_enrichver",
      "brawn", "brawn_enrichver",
      "wit", "wit_enrichver",
      "speed", "speed_enrichver",
      "size_name", "size_name_enrichver",
      "icon_url", "icon_url_enrichver",
      "art_url", "art_url_enrichver",
      "cell_habitat_name", "cell_habitat_name_enrichver",
      "cell_climate_name", "cell_climate_name_enrichver",
      "cell_continent_name", "cell_continent_name_enrichver",
      "location_district", "location_district_enrichver",
      "location_city", "location_city_enrichver",
      "location_state", "location_state_enrichver",
      "location_country", "location_country_enrichver",
      "location_country_code", "location_country_code_enrichver",
    ].join(", ");

    // Query item instances that have any field needing work
    const { data: itemCandidates, error: itemCandidatesErr } = await supabase
      .from("item_instances")
      .select(itemColumns)
      .or([
        `animal_class_name.is.null`,
        `animal_class_name_enrichver.is.null`,
        `animal_class_name_enrichver.neq.${pipelineVersion}`,
        `icon_url.is.null`,
        `icon_url_enrichver.is.null`,
        `icon_url_enrichver.neq.${pipelineVersion}`,
        `art_url.is.null`,
        `art_url_enrichver.is.null`,
        `art_url_enrichver.neq.${pipelineVersion}`,
        `cell_habitat_name.is.null`,
        `cell_habitat_name_enrichver.is.null`,
        `cell_habitat_name_enrichver.neq.${pipelineVersion}`,
        `location_city.is.null`,
        `location_city_enrichver.is.null`,
        `location_city_enrichver.neq.${pipelineVersion}`,
      ].join(","))
      .limit(200);

    if (itemCandidatesErr) throw new Error(`Failed to query item_instances: ${itemCandidatesErr.message}`);

    if (!itemCandidates || itemCandidates.length === 0) {
      console.log('[items] nothing to denormalize');
    } else {
      console.log(`[items] ${itemCandidates.length} candidates found`);
      // Score in TypeScript, pick top 50
      const scoredItems = (itemCandidates as ItemInstanceRow[]).map(row => ({
        row,
        score: itemFieldsNeedingWork(row, pipelineVersion),
      }));
      scoredItems.sort((a, b) => a.score - b.score);
      const batch = scoredItems.slice(0, 50).map(x => x.row);
      const minScore = scoredItems[0]?.score ?? 0;
      const maxScore = scoredItems[scoredItems.length - 1]?.score ?? 0;
      console.log(`[items] batch of ${batch.length} (scores: ${minScore}-${maxScore})`);

      // Collect unique definition_ids and cell_ids in the batch
      const definitionIds = [...new Set(batch.map(i => i.definition_id))];
      const cellIds = [...new Set(batch.map(i => i.acquired_in_cell_id).filter(Boolean))] as string[];

      // Fetch species data for all definition_ids in batch
      const speciesMap: Map<string, SpeciesRow> = new Map();
      if (definitionIds.length > 0) {
        const { data: speciesRows } = await supabase
          .from("species")
          .select("definition_id, animal_class, food_preference, climate, brawn, wit, speed, size, icon_url, art_url")
          .in("definition_id", definitionIds);
        if (speciesRows) {
          for (const s of speciesRows) {
            speciesMap.set(s.definition_id, s as SpeciesRow);
          }
        }
      }

      // Fetch cell_properties for all cell_ids in batch
      const cellMap: Map<string, any> = new Map();
      if (cellIds.length > 0) {
        const { data: cellRows } = await supabase
          .from("cell_properties")
          .select("cell_id, habitats, climate, continent, location_id")
          .in("cell_id", cellIds);
        if (cellRows) {
          for (const c of cellRows) {
            cellMap.set(c.cell_id, c);
          }
        }
      }

      // Collect all location_ids we need to walk (TEXT type, not number)
      const locationIdSet: Set<string> = new Set();
      for (const item of batch) {
        if (item.acquired_in_cell_id) {
          const cell = cellMap.get(item.acquired_in_cell_id);
          if (cell?.location_id) locationIdSet.add(String(cell.location_id));
        }
      }

      // Build location chain for each unique location_id
      // Walk location_nodes upward, building a map: location_id → { district, city, state, country }
      const locationChainMap: Map<string, Record<string, string>> = new Map();
      for (const rootId of locationIdSet) {
        const fields: Record<string, string> = {};
        let nodeId: string | null = rootId;
        let depth = 0;
        while (nodeId !== null && depth < 10) {
          depth++;
          const { data: node } = await supabase
            .from("location_nodes")
            .select("id, name, admin_level, parent_id")
            .eq("id", nodeId)
            .maybeSingle();
          if (!node) break;
          switch (node.admin_level) {
            case "district": fields.location_district = node.name; break;
            case "city": fields.location_city = node.name; break;
            case "state": fields.location_state = node.name; break;
            case "country": fields.location_country = node.name; break;
          }
          nodeId = node.parent_id ?? null;
        }
        locationChainMap.set(rootId, fields);
      }
      console.log(`[items] location chains resolved: ${locationChainMap.size} unique locations`);

      // Now update each item in the batch
      let batchUpdated = 0;
      for (const item of batch) {
        const updates: Record<string, unknown> = {};
        const species = speciesMap.get(item.definition_id);
        const cell = item.acquired_in_cell_id ? cellMap.get(item.acquired_in_cell_id) : null;
        const locationId: string | null = cell?.location_id ? String(cell.location_id) : null;
        const locationFields = locationId ? (locationChainMap.get(locationId) ?? {}) : {};

        // Species fields — only if species has animal_class (classification done)
        if (species?.animal_class !== null && species?.animal_class !== undefined) {
          if (item.animal_class_name === null || item.animal_class_name_enrichver !== pipelineVersion) {
            updates.animal_class_name = species.animal_class;
            updates.animal_class_name_enrichver = pipelineVersion;
          }
          if (item.food_preference_name === null || item.food_preference_name_enrichver !== pipelineVersion) {
            updates.food_preference_name = species.food_preference ?? null;
            updates.food_preference_name_enrichver = pipelineVersion;
          }
          if (item.climate_name === null || item.climate_name_enrichver !== pipelineVersion) {
            updates.climate_name = species.climate ?? null;
            updates.climate_name_enrichver = pipelineVersion;
          }
          if (item.brawn === null || item.brawn_enrichver !== pipelineVersion) {
            updates.brawn = species.brawn ?? null;
            updates.brawn_enrichver = pipelineVersion;
          }
          if (item.wit === null || item.wit_enrichver !== pipelineVersion) {
            updates.wit = species.wit ?? null;
            updates.wit_enrichver = pipelineVersion;
          }
          if (item.speed === null || item.speed_enrichver !== pipelineVersion) {
            updates.speed = species.speed ?? null;
            updates.speed_enrichver = pipelineVersion;
          }
          if (item.size_name === null || item.size_name_enrichver !== pipelineVersion) {
            updates.size_name = species.size ?? null;
            updates.size_name_enrichver = pipelineVersion;
          }
        }

        // Icon/art URL from species
        if (species?.icon_url !== null && species?.icon_url !== undefined) {
          if (item.icon_url === null || item.icon_url_enrichver !== pipelineVersion) {
            updates.icon_url = species.icon_url;
            updates.icon_url_enrichver = pipelineVersion;
          }
        }
        if (species?.art_url !== null && species?.art_url !== undefined) {
          if (item.art_url === null || item.art_url_enrichver !== pipelineVersion) {
            updates.art_url = species.art_url;
            updates.art_url_enrichver = pipelineVersion;
          }
        }

        // Cell properties
        if (cell) {
          if (item.cell_habitat_name === null || item.cell_habitat_name_enrichver !== pipelineVersion) {
            // habitats is a TEXT[] array — first element
            const habitats = cell.habitats;
            const firstHabitat = Array.isArray(habitats) && habitats.length > 0 ? habitats[0] : null;
            updates.cell_habitat_name = firstHabitat;
            updates.cell_habitat_name_enrichver = pipelineVersion;
          }
          if (item.cell_climate_name === null || item.cell_climate_name_enrichver !== pipelineVersion) {
            updates.cell_climate_name = cell.climate ?? null;
            updates.cell_climate_name_enrichver = pipelineVersion;
          }
          if (item.cell_continent_name === null || item.cell_continent_name_enrichver !== pipelineVersion) {
            updates.cell_continent_name = cell.continent ?? null;
            updates.cell_continent_name_enrichver = pipelineVersion;
          }
        }

        // Location fields
        if (Object.keys(locationFields).length > 0) {
          if (locationFields.location_district !== undefined &&
            (item.location_district === null || item.location_district_enrichver !== pipelineVersion)) {
            updates.location_district = locationFields.location_district;
            updates.location_district_enrichver = pipelineVersion;
          }
          if (locationFields.location_city !== undefined &&
            (item.location_city === null || item.location_city_enrichver !== pipelineVersion)) {
            updates.location_city = locationFields.location_city;
            updates.location_city_enrichver = pipelineVersion;
          }
          if (locationFields.location_state !== undefined &&
            (item.location_state === null || item.location_state_enrichver !== pipelineVersion)) {
            updates.location_state = locationFields.location_state;
            updates.location_state_enrichver = pipelineVersion;
          }
          if (locationFields.location_country !== undefined &&
            (item.location_country === null || item.location_country_enrichver !== pipelineVersion)) {
            updates.location_country = locationFields.location_country;
            updates.location_country_enrichver = pipelineVersion;
          }
          // location_country_code: not available from location_nodes for now
        }

        if (Object.keys(updates).length > 0) {
          const { error: updateErr } = await supabase
            .from("item_instances")
            .update(updates)
            .eq("id", item.id);
          if (updateErr) {
            errors.push(`Item ${item.id} update failed: ${updateErr.message}`);
          } else {
            batchUpdated++;
          }
        }
      }

      itemsEnriched = batchUpdated;
      console.log(`[items] enriched ${itemsEnriched} items`);
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    errors.push(`Item denormalization fatal: ${message}`);
    console.error(`[items] fatal: ${message}`);
  }

  const result = { species_enriched: speciesEnriched, item_stage: itemStage, items_enriched: itemsEnriched, errors };
  console.log(`[worker] done — species_enriched=${speciesEnriched} item_stage=${itemStage} items_enriched=${itemsEnriched} errors=${errors.length}`);
  if (errors.length > 0) {
    console.error(`[worker] errors: ${JSON.stringify(errors)}`);
  }

  await logEvent('worker_run', null, {
    metadata: {
      species_enriched: speciesEnriched,
      item_stage: itemStage,
      items_enriched: itemsEnriched,
      errors: errors.length,
      error_messages: errors.slice(0, 5), // cap at 5 to avoid huge payloads
      pipeline_version: pipelineVersion,
    },
    duration_ms: Date.now() - workerStartMs,
  });

  return new Response(JSON.stringify(result), {
    headers: { "Content-Type": "application/json" },
  });
});
