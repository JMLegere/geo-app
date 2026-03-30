import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── CORS headers (matches existing Edge Function pattern) ────────────────────

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ── LLM Providers (same pool as process-enrichment-queue) ────────────────────

interface Provider {
  name: string;
  url: string;
  keyEnv: string;
  model: string;
}

const PROVIDERS: Provider[] = [
  {
    name: "groq",
    url: "https://api.groq.com/openai/v1/chat/completions",
    keyEnv: "GROQ_API_KEY",
    model: "llama-3.3-70b-versatile",
  },
  {
    name: "zen-gpt5nano",
    url: "https://opencode.ai/zen/v1/chat/completions",
    keyEnv: "OPENCODE_ZEN_API_KEY",
    model: "gpt-5-nano",
  },
  {
    name: "zen-bigpickle",
    url: "https://opencode.ai/zen/v1/chat/completions",
    keyEnv: "OPENCODE_ZEN_API_KEY",
    model: "big-pickle",
  },
  {
    name: "zen-minimax",
    url: "https://opencode.ai/zen/v1/chat/completions",
    keyEnv: "OPENCODE_ZEN_API_KEY",
    model: "minimax-m2.5-free",
  },
  {
    name: "zen-mimo",
    url: "https://opencode.ai/zen/v1/chat/completions",
    keyEnv: "OPENCODE_ZEN_API_KEY",
    model: "mimo-v2-flash-free",
  },
  {
    name: "zen-nemotron",
    url: "https://opencode.ai/zen/v1/chat/completions",
    keyEnv: "OPENCODE_ZEN_API_KEY",
    model: "nemotron-3-super-free",
  },
];

// ── Constants ────────────────────────────────────────────────────────────────

const CATEGORIES = [
  "species",
  "conservation",
  "natural_science",
  "behavior",
  "milestone",
] as const;
type FactCategory = (typeof CATEGORIES)[number];

const TARGET_POOL_SIZE = 100;
const BATCH_SIZE = 5;

// ── Category-specific prompt blocks ─────────────────────────────────────────

const CATEGORY_PROMPTS: Record<FactCategory, string> = {
  species: `CATEGORY: Species Facts
Generate facts about specific real animal or plant species. Each fact should name the species.
Topics: extreme abilities, record-breaking traits, bizarre anatomy, unusual life cycles,
surprising intelligence, weird reproductive strategies, extreme survival adaptations.
IMPORTANT: Use real species with real scientifically documented traits. No myths.`,

  conservation: `CATEGORY: Conservation
Generate facts about habitat restoration, species recovery programs, protected areas,
and conservation techniques that have worked in the real world.
Topics: rewilding projects, marine protected areas, reforestation, captive breeding,
wildlife corridors, community-based conservation, invasive species removal, seed banks.
IMPORTANT: Include specific places, organizations, or quantified outcomes where possible.`,

  natural_science: `CATEGORY: Natural Sciences
Generate facts about geology, ecology, oceanography, meteorology, botany, evolutionary
biology, and earth science. NOT about specific animal behavior (that's a different category).
Topics: deep time, plate tectonics, ocean chemistry, soil science, atmospheric phenomena,
mycorrhizal networks, fossil records, convergent evolution, biogeochemistry, extremophiles.
IMPORTANT: Quantify where possible (ages, temperatures, distances, depths).`,

  behavior: `CATEGORY: Fauna & Flora Behavior
Generate facts about animal and plant behavior: migration, symbiosis, adaptation,
pollination, predator-prey dynamics, communication, social structures, tool use.
Topics: collective intelligence, mutualism, parasitism, courtship rituals, navigation,
hibernation, mimicry, warning signals, cooperative hunting, plant defenses.
IMPORTANT: Name the specific species exhibiting the behavior.`,

  milestone: `CATEGORY: Conservation Milestones
Generate facts about real, verified conservation achievements. These should be TIMELESS
milestones — not breaking news. Things that happened, were confirmed, and remain true.
Topics: species delisted from endangered, landmark treaties/laws, population recoveries,
habitat protections enacted, successful reintroductions, pollution cleanup milestones.
IMPORTANT: Include the year and specific numbers. Every fact must be historically accurate.`,
};

// ── Prompt builder ──────────────────────────────────────────────────────────

function buildPrompt(
  category: FactCategory,
  existingFacts: string[],
): string {
  const avoidClause =
    existingFacts.length > 0
      ? `\n\nAVOID DUPLICATING these existing facts (paraphrased or otherwise):\n${existingFacts.map((f, i) => `${i + 1}. ${f}`).join("\n")}`
      : "";

  return `You are a nature facts writer for a wildlife exploration game. Your facts appear on
loading screens — they should make players go "huh, cool" in under 5 seconds of reading.

${CATEGORY_PROMPTS[category]}

RULES:
- Write exactly ${BATCH_SIZE} facts as a JSON array of strings.
- Each fact MUST be one or two sentences, under 60 words.
- Each fact MUST be scientifically accurate and verifiable.
- Be specific: use real numbers, real species names, real places.
- No generic statements like "nature is amazing" or "biodiversity matters."
- No first person, no questions, no calls to action.
- Tone: informative, slightly awe-inspiring, concise.
- Do NOT repeat topics across the ${BATCH_SIZE} facts — each should cover a different subject.
${avoidClause}

Return ONLY a JSON array of ${BATCH_SIZE} strings. No markdown fences, no preamble.`;
}

// ── JSON extraction / validation ────────────────────────────────────────────

function extractJSON(raw: string): string {
  let cleaned = raw.trim();
  const fenceMatch = cleaned.match(/```(?:json)?\s*\n?([\s\S]*?)\n?\s*```/);
  if (fenceMatch) cleaned = fenceMatch[1].trim();
  if (cleaned.charCodeAt(0) === 0xfeff) cleaned = cleaned.slice(1);
  return cleaned;
}

function validateFacts(parsed: unknown): string[] | null {
  if (!Array.isArray(parsed)) return null;
  const facts: string[] = [];
  for (const item of parsed) {
    if (typeof item !== "string") return null;
    const trimmed = item.trim();
    if (trimmed.length < 20 || trimmed.length > 300) continue;
    facts.push(trimmed);
  }
  return facts.length > 0 ? facts : null;
}

// ── LLM call with provider rotation ─────────────────────────────────────────

async function generateFacts(
  providers: Provider[],
  category: FactCategory,
  existingFacts: string[],
): Promise<{ facts: string[]; providerName: string }> {
  const prompt = buildPrompt(category, existingFacts);

  for (const provider of providers) {
    const apiKey = Deno.env.get(provider.keyEnv);
    if (!apiKey) continue;

    try {
      const response = await fetch(provider.url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: provider.model,
          messages: [
            {
              role: "system",
              content:
                "You are a concise nature facts writer. Always respond with a JSON array of strings. No markdown.",
            },
            { role: "user", content: prompt },
          ],
          temperature: 0.9,
        }),
      });

      if (!response.ok) {
        const errBody = await response.text();
        console.error(
          `[facts] ${provider.name} API error ${response.status}: ${errBody.slice(0, 200)}`,
        );
        continue;
      }

      const body = await response.json();
      const text = body?.choices?.[0]?.message?.content;
      if (!text) {
        console.error(`[facts] Empty response from ${provider.name}`);
        continue;
      }

      // Parse — handle both bare arrays and {facts: [...]} wrappers
      let parsed: unknown;
      try {
        parsed = JSON.parse(extractJSON(text));
      } catch {
        console.error(
          `[facts] JSON parse failed from ${provider.name}: ${text.slice(0, 200)}`,
        );
        continue;
      }

      // Unwrap object wrappers (e.g. { "facts": [...] })
      if (
        typeof parsed === "object" &&
        parsed !== null &&
        !Array.isArray(parsed)
      ) {
        const values = Object.values(parsed as Record<string, unknown>);
        const arrayValue = values.find((v) => Array.isArray(v));
        if (arrayValue) parsed = arrayValue;
      }

      const facts = validateFacts(parsed);
      if (!facts) {
        console.error(
          `[facts] Validation failed from ${provider.name}: ${text.slice(0, 200)}`,
        );
        continue;
      }

      console.log(
        `[facts] Generated ${facts.length} ${category} facts via ${provider.name}`,
      );
      return { facts, providerName: provider.name };
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      console.error(`[facts] ${provider.name} error: ${message}`);
    }
  }

  throw new Error(
    `All ${providers.length} providers failed for category ${category}`,
  );
}

// ── Main Handler ─────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    // Check current pool size
    const { count, error: countErr } = await supabase
      .from("fun_facts")
      .select("*", { count: "exact", head: true });

    if (countErr) throw new Error(`Count query failed: ${countErr.message}`);

    const currentCount = count ?? 0;
    console.log(
      `[facts] current pool size: ${currentCount}, target: ${TARGET_POOL_SIZE}`,
    );

    if (currentCount >= TARGET_POOL_SIZE) {
      // Rotate: delete the 50 oldest facts to make room for fresh ones.
      const { data: oldest } = await supabase
        .from("fun_facts")
        .select("id")
        .order("created_at", { ascending: true })
        .limit(50);

      if (oldest && oldest.length > 0) {
        const ids = oldest.map((r: { id: number }) => r.id);
        const { error: delErr } = await supabase
          .from("fun_facts")
          .delete()
          .in("id", ids);

        if (delErr) {
          console.error(`[facts] rotation delete failed: ${delErr.message}`);
        } else {
          console.log(`[facts] rotated out ${ids.length} oldest facts`);
        }
      }
    }

    // Fetch existing facts to pass as dedup context to the LLM
    const { data: existingRows } = await supabase
      .from("fun_facts")
      .select("fact_text, category");

    const existingByCategory: Record<string, string[]> = {};
    for (const cat of CATEGORIES) existingByCategory[cat] = [];
    if (existingRows) {
      for (const row of existingRows) {
        existingByCategory[row.category]?.push(row.fact_text);
      }
    }

    // Pick category: weighted toward least-populated
    const categoryCounts: Record<string, number> = {};
    for (const cat of CATEGORIES) {
      categoryCounts[cat] = existingByCategory[cat]?.length ?? 0;
    }
    const sortedCats = [...CATEGORIES].sort(
      (a, b) => categoryCounts[a] - categoryCounts[b],
    );
    const pickPoolSize = Math.min(3, sortedCats.length);
    const selectedCategory =
      sortedCats[Math.floor(Math.random() * pickPoolSize)];

    console.log(
      `[facts] generating ${selectedCategory} (current: ${categoryCounts[selectedCategory]})`,
    );

    // Get available providers (shuffled for load distribution)
    const availableProviders = PROVIDERS.filter((p) =>
      Deno.env.get(p.keyEnv),
    );
    const shuffledProviders = [...availableProviders].sort(
      () => Math.random() - 0.5,
    );

    if (shuffledProviders.length === 0) {
      throw new Error("No LLM providers configured");
    }

    const { facts, providerName } = await generateFacts(
      shuffledProviders,
      selectedCategory,
      existingByCategory[selectedCategory] ?? [],
    );

    // Insert facts
    const inserts = facts.map((fact_text) => ({
      fact_text,
      category: selectedCategory,
      source: "llm" as const,
    }));

    const { error: insertErr } = await supabase
      .from("fun_facts")
      .insert(inserts);

    if (insertErr) {
      console.error(`[facts] Insert failed: ${insertErr.message}`);
      return new Response(
        JSON.stringify({ error: insertErr.message }),
        {
          status: 500,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    const result = {
      generated: facts.length,
      total: currentCount + facts.length,
      category: selectedCategory,
      provider: providerName,
    };
    console.log(`[facts] done — generated ${facts.length} ${selectedCategory} facts via ${providerName}`);

    return new Response(JSON.stringify(result), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`[facts] fatal: ${message}`);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
