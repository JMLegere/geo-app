import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ArtRequest {
  definition_id: string;
  scientific_name: string;
  common_name: string;
  asset_type: "icon" | "illustration";
  habitat?: string;
  climate?: string;
  brawn?: number;
  wit?: number;
  speed?: number;
}

interface BatchRequest {
  species: ArtRequest[];
}

interface BatchResult {
  definition_id: string;
  url: string;
  status: "generated" | "exists";
}

interface BatchError {
  definition_id: string;
  error: string;
}

const BUCKET = "species-art";
const MAX_BATCH_SIZE = 5;
const MAX_RETRIES = 3;
const BASE_DELAY_MS = 2000;

function buildPrompt(req: ArtRequest): string {
  if (req.asset_type === "icon") {
    return `Generate an image: Cute chibi-style character icon of a ${req.common_name} (${req.scientific_name}). Simple, adorable, round proportions, expressive eyes, clean outline. Transparent background, centered, facing slightly left. Style: Pokemon PC box sprite, soft colors, no text, no shadows, no ground. 96x96 pixels.`;
  }

  let poseDirection = "natural resting pose, alert but relaxed";
  if (req.brawn != null && req.wit != null && req.speed != null) {
    const max = Math.max(req.brawn!, req.wit!, req.speed!);
    if (req.brawn === max) poseDirection = "powerful stance, grounded, imposing";
    else if (req.speed === max) poseDirection = "dynamic motion, leaping, wind-swept, mid-stride";
    else if (req.wit === max) poseDirection = "alert and observant, clever posture, head tilted";
  }

  let climateLighting = "Soft natural daylight, gentle warmth";
  switch (req.climate) {
    case "tropic": climateLighting = "Warm golden tropical light, lush greens"; break;
    case "boreal": climateLighting = "Cool crisp northern light, muted tones"; break;
    case "frigid": climateLighting = "Cold blue-white arctic light, stark contrast"; break;
  }

  const habitatScene = req.habitat ?? "natural";
  return `Generate an image: Professional Pokemon TCG-style watercolor illustration of a ${req.common_name} (${req.scientific_name}). Pose: ${poseDirection}. Composition: Full body, 3/4 view, slightly off-center, breathing room. Background: Soft atmospheric ${habitatScene} scene, impressionistic, not competing with subject. ${climateLighting}. Style: Watercolor with visible brushstrokes, soft edges, translucent layers, luminous quality. Moderate saturation. Soft diffused lighting. No text, no labels, no borders, no card frame. 512x512 pixels.`;
}

async function generateImageWithRetry(
  prompt: string,
  apiKey: string,
  definitionId: string,
): Promise<Uint8Array> {
  let lastError: Error | null = null;

  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=${apiKey}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: {
              responseModalities: ["TEXT", "IMAGE"],
            },
          }),
        },
      );

      if (response.status === 429) {
        const delayMs = BASE_DELAY_MS * Math.pow(2, attempt);
        console.log(`[art-batch] rate limited for ${definitionId}, backing off ${delayMs}ms (attempt ${attempt + 1}/${MAX_RETRIES})`);
        await new Promise(r => setTimeout(r, delayMs));
        continue;
      }

      if (!response.ok) {
        const errText = await response.text();
        throw new Error(`Gemini API error ${response.status}: ${errText}`);
      }

      const data = await response.json();
      const candidates = data.candidates;
      if (!candidates || candidates.length === 0) {
        throw new Error("No candidates in Gemini response");
      }

      const parts = candidates[0].content?.parts;
      if (!parts) throw new Error("No parts in Gemini response");

      for (const part of parts) {
        if (part.inlineData?.mimeType?.startsWith("image/")) {
          const base64 = part.inlineData.data;
          const binaryString = atob(base64);
          const bytes = new Uint8Array(binaryString.length);
          for (let i = 0; i < binaryString.length; i++) {
            bytes[i] = binaryString.charCodeAt(i);
          }
          return bytes;
        }
      }

      throw new Error("No image found in Gemini response parts");
    } catch (err) {
      lastError = err instanceof Error ? err : new Error(String(err));
      if (attempt < MAX_RETRIES - 1) {
        const delayMs = BASE_DELAY_MS * Math.pow(2, attempt);
        console.log(`[art-batch] error for ${definitionId}, retrying in ${delayMs}ms (attempt ${attempt + 1}/${MAX_RETRIES}): ${lastError.message}`);
        await new Promise(r => setTimeout(r, delayMs));
      }
    }
  }

  throw lastError ?? new Error("Max retries exceeded");
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

  // Accept service role key for backfill scripts
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (serviceKey && token === serviceKey) return null;

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
    const body: BatchRequest = await req.json();
    const { species } = body;

    if (!Array.isArray(species) || species.length === 0) {
      return new Response(
        JSON.stringify({ error: "species array must have at least 1 item" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    if (species.length > MAX_BATCH_SIZE) {
      return new Response(
        JSON.stringify({ error: `Batch size cannot exceed ${MAX_BATCH_SIZE}` }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "GEMINI_API_KEY not configured" }),
        { status: 503, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    const results: BatchResult[] = [];
    const errors: BatchError[] = [];

    for (const sp of species) {
      try {
        if (!sp.definition_id || !sp.scientific_name || !sp.common_name || !sp.asset_type) {
          errors.push({ definition_id: sp.definition_id ?? "unknown", error: "Missing required fields" });
          continue;
        }

        const fileName = sp.asset_type === "icon"
          ? `${sp.definition_id}_icon.webp`
          : `${sp.definition_id}.webp`;

        // Check if exists
        const { data: existingFile } = await supabase.storage
          .from(BUCKET)
          .list("", { search: fileName });

        if (existingFile && existingFile.length > 0) {
          const url = `${supabaseUrl}/storage/v1/object/public/${BUCKET}/${fileName}`;
          results.push({ definition_id: sp.definition_id, url, status: "exists" });
          continue;
        }

        const prompt = buildPrompt(sp);
        console.log(`[art-batch] generating ${sp.asset_type} for ${sp.common_name} (${sp.definition_id})`);

        const imageBytes = await generateImageWithRetry(prompt, apiKey, sp.definition_id);

        const { error: uploadError } = await supabase.storage
          .from(BUCKET)
          .upload(fileName, imageBytes, {
            contentType: "image/webp",
            upsert: true,
          });

        if (uploadError) {
          throw new Error(`Upload failed: ${uploadError.message}`);
        }

        const url = `${supabaseUrl}/storage/v1/object/public/${BUCKET}/${fileName}`;

        // Update enrichment row
        const column = sp.asset_type === "icon" ? "icon_url" : "art_url";
        const { error: updateError } = await supabase
          .from("species_enrichment")
          .update({ [column]: url })
          .eq("definition_id", sp.definition_id);

        if (updateError) {
          console.error(`[art-batch] DB update failed (non-fatal): ${updateError.message}`);
        }

        console.log(`[art-batch] ${sp.asset_type} complete for ${sp.definition_id}`);
        results.push({ definition_id: sp.definition_id, url, status: "generated" });
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        console.error(`[art-batch] failed for ${sp.definition_id}: ${message}`);
        errors.push({ definition_id: sp.definition_id, error: message });
      }
    }

    return new Response(
      JSON.stringify({ results, errors }),
      { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  }
});
