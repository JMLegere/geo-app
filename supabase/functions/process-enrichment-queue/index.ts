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
const GEMINI_IMAGE_MODEL = "gemini-2.5-flash-image";
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

function buildArtPrompt(
  commonName: string,
  scientificName: string,
  assetType: "icon" | "illustration",
  enrichment?: { climate?: string | null; brawn?: number | null; wit?: number | null; speed?: number | null },
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

// Returns null on 429 (caller should stop art pass), throws on other errors after retries
async function generateAndUploadArt(
  supabase: any,
  supabaseUrl: string,
  geminiKey: string,
  definitionId: string,
  scientificName: string,
  commonName: string,
  assetType: "icon" | "illustration",
  enrichment?: { climate?: string | null; brawn?: number | null; wit?: number | null; speed?: number | null },
): Promise<string | null | "rate_limited"> {
  const fileName = assetType === "icon" ? `${definitionId}_icon.webp` : `${definitionId}.webp`;

  // Check if already exists in storage
  const { data: existingFile } = await supabase.storage.from(ART_BUCKET).list("", { search: fileName });
  if (existingFile && existingFile.length > 0) {
    const url = `${supabaseUrl}/storage/v1/object/public/${ART_BUCKET}/${fileName}`;
    console.log(`[art] ${definitionId} ${assetType} already in storage`);
    await logEvent('art_skipped', definitionId, {
      asset_type: assetType,
      metadata: { reason: 'already_in_storage' },
    });
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
        if (attempt === ART_MAX_RETRIES - 1) return "rate_limited";
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
          for (let i = 0; i < binaryString.length; i++) imageBytes[i] = binaryString.charCodeAt(i);
          break;
        }
      }
      if (!imageBytes) throw new Error("No image in Gemini response");

      const { error: uploadError } = await supabase.storage
        .from(ART_BUCKET)
        .upload(fileName, imageBytes, { contentType: "image/webp", upsert: true });
      if (uploadError) throw new Error(`Upload failed: ${uploadError.message}`);

      const url = `${supabaseUrl}/storage/v1/object/public/${ART_BUCKET}/${fileName}`;

      const column = assetType === "icon" ? "icon_url" : "art_url";
      await supabase.from("species_enrichment").update({ [column]: url }).eq("definition_id", definitionId);

      console.log(`[art] ${assetType} generated for ${definitionId}: ${url}`);
      return url;
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      console.error(`[art] ${assetType} attempt ${attempt + 1} failed for ${definitionId}: ${message}`);
      if (attempt < ART_MAX_RETRIES - 1) await new Promise(r => setTimeout(r, ART_BASE_DELAY_MS * Math.pow(2, attempt)));
    }
  }
  return null;
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

  // ── Pass 1: Classification ───────────────────────────────────────────────

  try {
    const availableProviders = PROVIDERS.filter(p => Deno.env.get(p.keyEnv));
    if (availableProviders.length === 0) {
      errors.push("Pass 1 skipped: no AI provider API keys configured");
    } else {
      // Get distinct definition_ids that have been discovered
      const { data: discoveredRows, error: instancesErr } = await supabase
        .from("item_instances")
        .select("definition_id")
        .limit(10000);

      if (instancesErr) throw new Error(`Failed to query item_instances: ${instancesErr.message}`);

      const uniqueIds = [...new Set((discoveredRows ?? []).map((r: any) => r.definition_id))];

      if (uniqueIds.length > 0) {
        const { data: needsClassification, error: speciesErr } = await supabase
          .from("species")
          .select("definition_id, scientific_name, common_name, taxonomic_class")
          .is("animal_class", null)
          .in("definition_id", uniqueIds)
          .order("definition_id")
          .limit(10);

        if (speciesErr) throw new Error(`Failed to query species: ${speciesErr.message}`);

        const toClassify = (needsClassification ?? []) as SpeciesRow[];
        if (toClassify.length === 0) {
          console.log('[pass1] nothing to classify');
        }

        for (const species of toClassify) {
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

          // Rate limiting: 1s between LLM calls
          await new Promise(r => setTimeout(r, 1000));
        }
      }
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    errors.push(`Pass 1 fatal: ${message}`);
    console.error(`[pass1] fatal: ${message}`);
  }

  // ── Pass 2: Art Generation ───────────────────────────────────────────────

  try {
    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey) {
      errors.push("Pass 2 skipped: GEMINI_API_KEY not set");
    } else {
      // Get distinct definition_ids that have been discovered
      const { data: discoveredRows, error: instancesErr } = await supabase
        .from("item_instances")
        .select("definition_id")
        .limit(10000);

      if (instancesErr) throw new Error(`Failed to query item_instances: ${instancesErr.message}`);

      const uniqueIds = [...new Set((discoveredRows ?? []).map((r: any) => r.definition_id))];

      if (uniqueIds.length > 0) {
        const { data: needsArt, error: artErr } = await supabase
          .from("species")
          .select("definition_id, scientific_name, common_name, animal_class, climate, brawn, wit, speed, icon_url, art_url, enriched_at")
          .not("animal_class", "is", null)
          .in("definition_id", uniqueIds)
          .or("icon_url.is.null,art_url.is.null")
          .order("enriched_at", { ascending: true })
          .limit(5);

        if (artErr) throw new Error(`Failed to query species for art: ${artErr.message}`);

        const toGenerate = (needsArt ?? []) as SpeciesRow[];
        if (toGenerate.length === 0) {
          console.log('[pass2] nothing to generate');
        }

        let rateLimited = false;

        for (const species of toGenerate) {
          if (rateLimited) break;

          const enrichmentCtx = {
            climate: species.climate,
            brawn: species.brawn,
            wit: species.wit,
            speed: species.speed,
          };

          // Generate icon if missing
          if (!species.icon_url) {
            const iconStartMs = Date.now();
            const result = await generateAndUploadArt(
              supabase, supabaseUrl, geminiKey,
              species.definition_id, species.scientific_name, species.common_name,
              "icon", enrichmentCtx,
            );
            if (result === "rate_limited") {
              rateLimited = true;
              errors.push("Pass 2 stopped: Gemini rate limit hit");
              await logEvent('rate_limited', species.definition_id, {
                asset_type: 'icon',
                provider_name: 'gemini',
              });
              break;
            }
            if (result) {
              icons++;
              await logEvent('art_success', species.definition_id, {
                asset_type: 'icon',
                duration_ms: Date.now() - iconStartMs,
                provider_name: 'gemini',
              });
            } else if (result === null) {
              await logEvent('art_error', species.definition_id, {
                asset_type: 'icon',
                error_message: 'All retries exhausted',
                duration_ms: Date.now() - iconStartMs,
                provider_name: 'gemini',
              });
            }
            await new Promise(r => setTimeout(r, 7000));
          }

          // Generate illustration if missing (and not rate-limited)
          if (!rateLimited && !species.art_url) {
            const illustrationStartMs = Date.now();
            const result = await generateAndUploadArt(
              supabase, supabaseUrl, geminiKey,
              species.definition_id, species.scientific_name, species.common_name,
              "illustration", enrichmentCtx,
            );
            if (result === "rate_limited") {
              rateLimited = true;
              errors.push("Pass 2 stopped: Gemini rate limit hit");
              await logEvent('rate_limited', species.definition_id, {
                asset_type: 'illustration',
                provider_name: 'gemini',
              });
              break;
            }
            if (result) {
              illustrations++;
              await logEvent('art_success', species.definition_id, {
                asset_type: 'illustration',
                duration_ms: Date.now() - illustrationStartMs,
                provider_name: 'gemini',
              });
            } else if (result === null) {
              await logEvent('art_error', species.definition_id, {
                asset_type: 'illustration',
                error_message: 'All retries exhausted',
                duration_ms: Date.now() - illustrationStartMs,
                provider_name: 'gemini',
              });
            }
            await new Promise(r => setTimeout(r, 7000));
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
