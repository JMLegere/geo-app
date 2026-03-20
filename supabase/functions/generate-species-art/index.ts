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
  // For illustration pose/mood:
  habitat?: string;
  climate?: string;
  brawn?: number;
  wit?: number;
  speed?: number;
}

const BUCKET = "species-art";

function buildPrompt(req: ArtRequest): string {
  if (req.asset_type === "icon") {
    return `Generate an image: Cute chibi-style character icon of a ${req.common_name} (${req.scientific_name}). Simple, adorable, round proportions, expressive eyes, clean outline. Transparent background, centered, facing slightly left. Style: Pokemon PC box sprite, soft colors, no text, no shadows, no ground. 96x96 pixels.`;
  }

  // Illustration — incorporate identity
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

async function generateImage(prompt: string, apiKey: string): Promise<Uint8Array> {
  // Use Gemini API with image generation
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=${apiKey}`,
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

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Gemini API error ${response.status}: ${errText}`);
  }

  const data = await response.json();
  
  // Extract image from response
  const candidates = data.candidates;
  if (!candidates || candidates.length === 0) {
    throw new Error("No candidates in Gemini response");
  }
  
  const parts = candidates[0].content?.parts;
  if (!parts) throw new Error("No parts in Gemini response");
  
  for (const part of parts) {
    if (part.inlineData?.mimeType?.startsWith("image/")) {
      const base64 = part.inlineData.data;
      // Convert base64 to Uint8Array
      const binaryString = atob(base64);
      const bytes = new Uint8Array(binaryString.length);
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
      }
      return bytes;
    }
  }
  
  throw new Error("No image found in Gemini response parts");
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
    const body: ArtRequest = await req.json();
    const { definition_id, scientific_name, common_name, asset_type } = body;

    if (!definition_id || !scientific_name || !common_name || !asset_type) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: definition_id, scientific_name, common_name, asset_type" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    if (asset_type !== "icon" && asset_type !== "illustration") {
      return new Response(
        JSON.stringify({ error: "asset_type must be 'icon' or 'illustration'" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    // Check if art already exists in storage
    const fileName = asset_type === "icon"
      ? `${definition_id}_icon.webp`
      : `${definition_id}.webp`;

    const { data: existingFile } = await supabase.storage
      .from(BUCKET)
      .list("", { search: fileName });

    if (existingFile && existingFile.length > 0) {
      const url = `${supabaseUrl}/storage/v1/object/public/${BUCKET}/${fileName}`;
      console.log(`[art] ${definition_id} ${asset_type} already exists: ${url}`);
      return new Response(
        JSON.stringify({ url, status: "exists" }),
        { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    // Generate image
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "GEMINI_API_KEY not configured" }),
        { status: 503, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    const prompt = buildPrompt(body);
    console.log(`[art] generating ${asset_type} for ${common_name} (${definition_id})`);
    
    const imageBytes = await generateImage(prompt, apiKey);
    console.log(`[art] generated ${imageBytes.length} bytes for ${definition_id}`);

    // Upload to storage
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
    const column = asset_type === "icon" ? "icon_url" : "art_url";
    const { error: updateError } = await supabase
      .from("species_enrichment")
      .update({ [column]: url })
      .eq("definition_id", definition_id);

    if (updateError) {
      console.error(`[art] DB update failed (non-fatal): ${updateError.message}`);
    }

    console.log(`[art] ${asset_type} complete for ${definition_id}: ${url}`);
    return new Response(
      JSON.stringify({ url, status: "generated" }),
      { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    const statusCode = (err as any).statusCode ?? 500;
    console.error(`[art] error: ${message}`);
    return new Response(
      JSON.stringify({ error: message }),
      { status: statusCode, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  }
});
