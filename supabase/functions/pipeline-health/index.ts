import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Hourly pipeline health summary → ntfy push notification.
// Scheduled via pg_cron: SELECT cron.schedule('pipeline_health_hourly', '0 * * * *', ...)

serve(async (_req: Request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const ntfyTopic = Deno.env.get("NTFY_TOPIC") || "earthnova-enrich-pipeline";
  const supabase = createClient(supabaseUrl, serviceKey);

  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();

  // 1. Species enriched in last hour
  const { count: enrichedLastHour } = await supabase
    .from("species")
    .select("definition_id", { count: "exact", head: true })
    .gte("enriched_at", oneHourAgo);

  // 2. Total pipeline coverage
  const { count: totalSpecies } = await supabase
    .from("species")
    .select("definition_id", { count: "exact", head: true });

  const { count: classified } = await supabase
    .from("species")
    .select("definition_id", { count: "exact", head: true })
    .not("animal_class", "is", null);

  const { count: withIcon } = await supabase
    .from("species")
    .select("definition_id", { count: "exact", head: true })
    .not("icon_url", "is", null);

  const { count: withArt } = await supabase
    .from("species")
    .select("definition_id", { count: "exact", head: true })
    .not("art_url", "is", null);

  // 3. Recent errors from app_logs
  const { data: recentErrors } = await supabase
    .from("app_logs")
    .select("lines")
    .gte("created_at", oneHourAgo)
    .like("lines", "%error%")
    .order("created_at", { ascending: false })
    .limit(5);

  const errorCount = recentErrors?.length ?? 0;

  // 4. Pipeline stall detection — last enrichment timestamp
  const { data: lastEnriched } = await supabase
    .from("species")
    .select("enriched_at")
    .not("enriched_at", "is", null)
    .order("enriched_at", { ascending: false })
    .limit(1);

  const lastEnrichedAt = lastEnriched?.[0]?.enriched_at;
  const hoursSinceLastEnrichment = lastEnrichedAt
    ? Math.round((Date.now() - new Date(lastEnrichedAt).getTime()) / 3600000)
    : 999;

  const isStalled = hoursSinceLastEnrichment > 2;
  const pctClassified = totalSpecies ? ((classified ?? 0) / totalSpecies * 100).toFixed(1) : "?";

  // 5. Build notification
  const lines = [
    `Last hour: ${enrichedLastHour ?? 0} species enriched`,
    `Total: ${classified ?? 0}/${totalSpecies ?? 0} classified (${pctClassified}%)`,
    `Icons: ${withIcon ?? 0} | Art: ${withArt ?? 0}`,
    `Last enrichment: ${hoursSinceLastEnrichment}h ago`,
  ];

  if (isStalled) {
    lines.push(`⚠️ STALLED — no enrichment in ${hoursSinceLastEnrichment}h`);
  }
  if (errorCount > 0) {
    lines.push(`${errorCount} error log entries in last hour`);
  }

  const title = isStalled
    ? `🚨 Pipeline STALLED (${hoursSinceLastEnrichment}h)`
    : enrichedLastHour && enrichedLastHour > 0
      ? `✅ Pipeline: +${enrichedLastHour} species/hr (${pctClassified}%)`
      : `⏸️ Pipeline idle (${pctClassified}% classified)`;

  const priority = isStalled ? "high" : "low";
  const tags = isStalled ? "rotating_light" : enrichedLastHour && enrichedLastHour > 0 ? "heavy_check_mark" : "zzz";

  try {
    await fetch(`https://ntfy.sh/${ntfyTopic}`, {
      method: "POST",
      headers: { "Title": title, "Priority": priority, "Tags": tags },
      body: lines.join("\n"),
    });
  } catch (err) {
    console.error(`[ntfy] failed: ${err}`);
  }

  const result = {
    enriched_last_hour: enrichedLastHour,
    total: totalSpecies,
    classified,
    with_icon: withIcon,
    with_art: withArt,
    stalled: isStalled,
    hours_since_last: hoursSinceLastEnrichment,
  };

  console.log(`[pipeline-health] ${JSON.stringify(result)}`);
  return new Response(JSON.stringify(result), {
    headers: { "Content-Type": "application/json" },
  });
});
