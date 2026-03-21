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

function buildArtPrompt(
  commonName: string,
  scientificName: string,
  assetType: "icon" | "illustration",
  enrichment?: { climate?: string | null; brawn?: number | null; wit?: number | null; speed?: number | null; habitat?: string | null; food_preference?: string | null; animal_class?: string | null },
): string {
  if (assetType === "icon") {
    return `Cute chibi character portrait of a ${commonName} (${scientificName}).
Style: Pokémon PC box icon — tiny, round, expressive, instantly
recognizable from silhouette alone. Simplified but species-accurate
features. Big expressive eyes, soft rounded proportions, friendly
and appealing even if the real animal is scary.

Front-facing or slight 3/4 view. Warm soft cel-shading with clean
outlines. 4-5 color tones, smooth anti-aliased edges. Head and upper
body only — no full body, no legs cut off. Must read clearly at 32px.

Render on a perfectly transparent background (alpha = 0).
No ground plane, no drop shadow, no glow, no background elements.
Just the creature, nothing else. Output as PNG with transparency.`;
  }

  // Action mapping from food_preference
  let action = "resting calmly in its natural habitat";
  switch (enrichment?.food_preference) {
    case "critter": action = "stalking or pouncing on small prey, predatory focus"; break;
    case "fish": action = "diving into water or catching a fish, splash and motion"; break;
    case "fruit": action = "reaching for or eating ripe fruit from a branch"; break;
    case "grub": action = "pecking at the ground or probing bark for insects"; break;
    case "nectar": action = "hovering at or perched on a flower, feeding"; break;
    case "seed": action = "foraging on the ground among scattered seeds or grasses"; break;
    case "veg": action = "grazing on fresh vegetation or browsing leafy branches"; break;
  }

  // Pose modifier from dominant stat
  let poseModifier = "Natural and relaxed in the moment";
  if (enrichment?.brawn != null && enrichment?.wit != null && enrichment?.speed != null) {
    const max = Math.max(enrichment.brawn, enrichment.wit, enrichment.speed);
    if (enrichment.brawn === max) poseModifier = "Powerful, muscular, dominant presence in the frame";
    else if (enrichment.speed === max) poseModifier = "Captured mid-motion, dynamic angle, sense of velocity";
    else if (enrichment.wit === max) poseModifier = "Alert eyes, watchful, cunning expression";
  }

  let habitatAtmosphere = "Soft natural outdoor setting";
  switch (enrichment?.habitat) {
    case "forest": habitatAtmosphere = "Dappled green light filtering through a forest canopy"; break;
    case "plains": habitatAtmosphere = "Open golden grassland with warm horizon light"; break;
    case "freshwater": habitatAtmosphere = "Misty riverbank with soft teal reflections"; break;
    case "saltwater": habitatAtmosphere = "Coastal scene with ocean spray and deep blue atmosphere"; break;
    case "swamp": habitatAtmosphere = "Lush wetland with filtered olive-green light"; break;
    case "mountain": habitatAtmosphere = "Rocky alpine scene with cool slate-grey mist"; break;
    case "desert": habitatAtmosphere = "Warm amber haze over dry sandy terrain"; break;
  }

  let climateLighting = "Soft natural daylight, gentle warmth";
  switch (enrichment?.climate) {
    case "tropic": climateLighting = "Warm golden tropical light, lush greens"; break;
    case "boreal": climateLighting = "Cool crisp northern light, muted tones"; break;
    case "frigid": climateLighting = "Cold blue-white arctic light, stark contrast"; break;
  }

  return `Oil painting illustration of a ${commonName} (${scientificName}) in the style of
classic Magic: The Gathering and Pokémon TCG card art.

The animal is ${action}. ${poseModifier}.
Setting: ${habitatAtmosphere}. ${climateLighting}.

Composition: Dramatic 3/4 view, slightly low angle to make the creature
feel heroic. The animal fills most of the frame — this is a portrait,
not a landscape. Shallow depth of field, background atmospheric and
painterly.

Technique: Rich oil painting style — visible brushwork, bold color,
strong value contrast, dramatic lighting with a clear light source.
Painterly realism, not photorealistic. Saturated but not garish.
Think Rebecca Guay, Terese Nielsen, Mitsuhiro Arita.

Avoid: Centered composition, flat lighting, white/blank backgrounds,
cartoon style, digital airbrush look, text, labels, borders, frames.`;
}

// Rotates through IMAGE_PROVIDERS; returns { url, provider } on success,
// "rate_limited" if all providers are exhausted/rate-limited, null on total failure.
async function generateAndUploadArt(
  supabase: any,
  supabaseUrl: string,
  definitionId: string,
  scientificName: string,
  commonName: string,
  assetType: "icon" | "illustration",
  enrichment?: { climate?: string | null; brawn?: number | null; wit?: number | null; speed?: number | null; habitat?: string | null; food_preference?: string | null; animal_class?: string | null },
  logEvent?: (type: string, defId: string | null, extra: Record<string, unknown>) => Promise<void>,
): Promise<{ url: string; provider: string } | "rate_limited" | null> {
  const filePrefix = assetType === "icon" ? `${definitionId}_icon` : definitionId;

  // Check if already exists in storage (any extension).
  const { data: existingFile } = await supabase.storage.from(ART_BUCKET).list("", { search: filePrefix });
  const existing = existingFile?.find((f: any) => f.name.startsWith(filePrefix));
  if (existing) {
    const url = `${supabaseUrl}/storage/v1/object/public/${ART_BUCKET}/${existing.name}`;
    console.log(`[art] ${definitionId} ${assetType} already in storage`);
    if (logEvent) await logEvent('art_skipped', definitionId, { asset_type: assetType, metadata: { reason: 'already_in_storage' } });
    return { url, provider: "cache" };
  }

  const prompt = buildArtPrompt(commonName, scientificName, assetType, enrichment);

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
      // Find one classified species that needs art.
      const { data: needsArt, error: artErr } = await supabase
        .from("species")
        .select("definition_id, scientific_name, common_name, animal_class, food_preference, climate, brawn, wit, speed, icon_url, art_url, enriched_at, habitats_json")
        .not("animal_class", "is", null)
        .or("icon_url.is.null,art_url.is.null")
        .order("enriched_at", { ascending: true })
        .limit(1)
        .maybeSingle();

      if (artErr) throw new Error(`Failed to query species for art: ${artErr.message}`);

      if (!needsArt) {
        console.log('[pass2] nothing to generate');
      } else {
        const species = needsArt as SpeciesRow;

        const enrichmentCtx = {
          climate: species.climate,
          brawn: species.brawn,
          wit: species.wit,
          speed: species.speed,
          habitat: parseFirstHabitat(species.habitats_json),
          food_preference: species.food_preference,
          animal_class: species.animal_class,
        };

        // Generate icon if missing
        if (!species.icon_url) {
          const result = await generateAndUploadArt(
            supabase, supabaseUrl,
            species.definition_id, species.scientific_name, species.common_name,
            "icon", enrichmentCtx, logEvent,
          );
          if (result === "rate_limited") {
            errors.push("Pass 2 stopped: all image providers rate limited");
          } else if (result) {
            icons++;
          }
        }

        // Generate illustration if missing
        if (!species.art_url && icons === 0) {
          // Only attempt illustration if we didn't just generate an icon
          // (keep each invocation light).
          const result = await generateAndUploadArt(
            supabase, supabaseUrl,
            species.definition_id, species.scientific_name, species.common_name,
            "illustration", enrichmentCtx, logEvent,
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
