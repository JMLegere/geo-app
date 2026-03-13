import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// --- Types ---

const ADMIN_LEVELS = [
  "world",
  "continent",
  "country",
  "state",
  "city",
  "district",
] as const;
type AdminLevel = (typeof ADMIN_LEVELS)[number];

interface EnrichRequest {
  cell_id: string;
  lat: number;
  lon: number;
}

interface LocationNode {
  id: string;
  name: string;
  admin_level: AdminLevel;
  parent_id: string | null;
  osm_id: number | null;
}

interface NominatimAddress {
  country?: string;
  country_code?: string;
  state?: string;
  province?: string;
  county?: string;
  city?: string;
  town?: string;
  village?: string;
  suburb?: string;
  neighbourhood?: string;
  quarter?: string;
}

// --- Continent from country code ---

const COUNTRY_TO_CONTINENT: Record<string, string> = {
  // North America
  us: "northAmerica", ca: "northAmerica", mx: "northAmerica",
  gt: "northAmerica", bz: "northAmerica", sv: "northAmerica",
  hn: "northAmerica", ni: "northAmerica", cr: "northAmerica",
  pa: "northAmerica", cu: "northAmerica", jm: "northAmerica",
  ht: "northAmerica", do: "northAmerica", tt: "northAmerica",
  bs: "northAmerica", bb: "northAmerica", ag: "northAmerica",
  dm: "northAmerica", gd: "northAmerica", kn: "northAmerica",
  lc: "northAmerica", vc: "northAmerica", pr: "northAmerica",
  // South America
  br: "southAmerica", ar: "southAmerica", co: "southAmerica",
  pe: "southAmerica", ve: "southAmerica", cl: "southAmerica",
  ec: "southAmerica", bo: "southAmerica", py: "southAmerica",
  uy: "southAmerica", gy: "southAmerica", sr: "southAmerica",
  gf: "southAmerica",
  // Europe
  gb: "europe", fr: "europe", de: "europe", it: "europe",
  es: "europe", pt: "europe", nl: "europe", be: "europe",
  at: "europe", ch: "europe", ie: "europe", pl: "europe",
  cz: "europe", sk: "europe", hu: "europe", ro: "europe",
  bg: "europe", hr: "europe", si: "europe", rs: "europe",
  ba: "europe", me: "europe", mk: "europe", al: "europe",
  gr: "europe", dk: "europe", se: "europe", no: "europe",
  fi: "europe", ee: "europe", lv: "europe", lt: "europe",
  ua: "europe", by: "europe", md: "europe", lu: "europe",
  mt: "europe", cy: "europe", is: "europe", li: "europe",
  mc: "europe", sm: "europe", va: "europe", ad: "europe",
  xk: "europe",
  // Asia
  cn: "asia", jp: "asia", kr: "asia", in: "asia",
  id: "asia", th: "asia", vn: "asia", ph: "asia",
  my: "asia", sg: "asia", mm: "asia", kh: "asia",
  la: "asia", bd: "asia", lk: "asia", np: "asia",
  pk: "asia", af: "asia", ir: "asia", iq: "asia",
  sa: "asia", ae: "asia", om: "asia", ye: "asia",
  jo: "asia", lb: "asia", sy: "asia", il: "asia",
  ps: "asia", kw: "asia", bh: "asia", qa: "asia",
  tr: "asia", ge: "asia", am: "asia", az: "asia",
  kz: "asia", uz: "asia", tm: "asia", kg: "asia",
  tj: "asia", mn: "asia", bt: "asia", mv: "asia",
  bn: "asia", tl: "asia", tw: "asia", kp: "asia",
  ru: "asia",
  // Africa
  ng: "africa", za: "africa", eg: "africa", ke: "africa",
  et: "africa", gh: "africa", tz: "africa", ug: "africa",
  dz: "africa", ma: "africa", tn: "africa", ly: "africa",
  sd: "africa", ss: "africa", cm: "africa", ci: "africa",
  sn: "africa", ml: "africa", bf: "africa", ne: "africa",
  td: "africa", cf: "africa", cg: "africa", cd: "africa",
  ga: "africa", gq: "africa", ao: "africa", mz: "africa",
  mg: "africa", zm: "africa", zw: "africa", bw: "africa",
  na: "africa", sz: "africa", ls: "africa", mw: "africa",
  rw: "africa", bi: "africa", so: "africa", dj: "africa",
  er: "africa", mr: "africa", gm: "africa", gw: "africa",
  sl: "africa", lr: "africa", tg: "africa", bj: "africa",
  mu: "africa", sc: "africa", cv: "africa", st: "africa",
  km: "africa",
  // Oceania
  au: "oceania", nz: "oceania", pg: "oceania", fj: "oceania",
  sb: "oceania", vu: "oceania", ws: "oceania", to: "oceania",
  ki: "oceania", fm: "oceania", mh: "oceania", pw: "oceania",
  nr: "oceania", tv: "oceania",
};

function continentFromCountryCode(code: string): string {
  return COUNTRY_TO_CONTINENT[code.toLowerCase()] ?? "europe";
}

// --- Nominatim ---

const NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse";
const USER_AGENT = "EarthNova-Game/1.0 (supabase-edge-function; contact@earthnova.app)";

interface NominatimResponse {
  place_id: number;
  osm_type: string;
  osm_id: number;
  address: NominatimAddress;
}

async function reverseGeocode(
  lat: number,
  lon: number,
): Promise<NominatimResponse> {
  const url = new URL(NOMINATIM_URL);
  url.searchParams.set("lat", lat.toString());
  url.searchParams.set("lon", lon.toString());
  url.searchParams.set("format", "jsonv2");
  url.searchParams.set("addressdetails", "1");
  url.searchParams.set("zoom", "18"); // max detail

  const resp = await fetch(url.toString(), {
    headers: { "User-Agent": USER_AGENT },
  });

  if (!resp.ok) {
    throw new Error(`Nominatim ${resp.status}: ${await resp.text()}`);
  }

  return resp.json();
}

// --- Hierarchy builder ---

function makeId(level: AdminLevel, name: string): string {
  const slug = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_|_$/g, "");
  return `${level}_${slug}`;
}

function buildHierarchy(
  address: NominatimAddress,
  nominatimOsmId?: number,
): LocationNode[] {
  const nodes: LocationNode[] = [];

  // World (singleton root)
  nodes.push({
    id: "world",
    name: "World",
    admin_level: "world",
    parent_id: null,
    osm_id: null,
  });

  // Continent (derived from country code)
  const countryCode = address.country_code ?? "";
  const continentName = continentFromCountryCode(countryCode);
  const continentId = makeId("continent", continentName);
  nodes.push({
    id: continentId,
    name: continentName,
    admin_level: "continent",
    parent_id: "world",
    osm_id: null,
  });

  // Country
  const countryName = address.country;
  if (!countryName) return nodes;
  const countryId = makeId("country", countryName);
  nodes.push({
    id: countryId,
    name: countryName,
    admin_level: "country",
    parent_id: continentId,
    osm_id: null,
  });

  // State / Province
  const stateName = address.state ?? address.province;
  let stateId: string | null = null;
  if (stateName) {
    stateId = makeId("state", `${countryCode}_${stateName}`);
    nodes.push({
      id: stateId,
      name: stateName,
      admin_level: "state",
      parent_id: countryId,
      osm_id: null,
    });
  }

  // City / Town / Village
  const cityName = address.city ?? address.town ?? address.village;
  let cityId: string | null = null;
  if (cityName) {
    const cityParent = stateId ?? countryId;
    cityId = makeId("city", `${countryCode}_${cityName}`);
    nodes.push({
      id: cityId,
      name: cityName,
      admin_level: "city",
      parent_id: cityParent,
      osm_id: null,
    });
  }

  const districtName =
    address.suburb ?? address.neighbourhood ?? address.quarter;
  if (districtName) {
    const districtParent = cityId ?? stateId ?? countryId;
    const districtId = makeId(
      "district",
      `${countryCode}_${districtName}`,
    );
    nodes.push({
      id: districtId,
      name: districtName,
      admin_level: "district",
      parent_id: districtParent,
      osm_id: null,
    });
  }

  // Attach Nominatim's osm_id to the deepest resolved node.
  if (nominatimOsmId != null && nodes.length > 0) {
    const deepest = nodes[nodes.length - 1];
    deepest.osm_id = nominatimOsmId;
  }

  return nodes;
}

// --- Auth ---

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

// --- Batch types ---

interface BatchCellInput {
  cell_id: string;
  lat: number;
  lon: number;
}

interface BatchResultItem {
  cell_id: string;
  status: "enriched" | "already_enriched" | "no_location_data";
  location_id?: string;
  hierarchy?: Array<{ id: string; name: string; level: string }>;
}

interface BatchErrorItem {
  cell_id: string;
  error: string;
}

// --- Rate-limit delay ---

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

const NOMINATIM_DELAY_MS = 1100; // 1.1s between calls — Nominatim rate limit is 1 req/sec
const MAX_BATCH_SIZE = 25;

// --- Main handler ---

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  const authResponse = await validateAuth(req);
  if (authResponse) return authResponse;

  try {
    const body = await req.json();
    const cells: BatchCellInput[] = body?.cells;

    // Batch-level validation
    if (!Array.isArray(cells) || cells.length === 0) {
      return new Response(
        JSON.stringify({ error: "cells must be a non-empty array" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    if (cells.length > MAX_BATCH_SIZE) {
      return new Response(
        JSON.stringify({
          error: `Batch too large: ${cells.length} cells (max ${MAX_BATCH_SIZE})`,
        }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    // Per-cell input validation — collect bad cells up front
    const validationErrors: BatchErrorItem[] = [];
    const validCells: BatchCellInput[] = [];

    for (const cell of cells) {
      if (
        !cell.cell_id ||
        typeof cell.cell_id !== "string" ||
        typeof cell.lat !== "number" ||
        typeof cell.lon !== "number"
      ) {
        validationErrors.push({
          cell_id: cell.cell_id ?? "(missing)",
          error: "Missing or invalid fields: cell_id (string), lat (number), lon (number) required",
        });
        continue;
      }

      if (cell.lat < -90 || cell.lat > 90 || cell.lon < -180 || cell.lon > 180) {
        validationErrors.push({
          cell_id: cell.cell_id,
          error: "Invalid coordinates: lat must be [-90,90], lon must be [-180,180]",
        });
        continue;
      }

      validCells.push(cell);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const results: BatchResultItem[] = [];
    const errors: BatchErrorItem[] = [...validationErrors];
    let nominatimCallCount = 0;

    for (const cell of validCells) {
      try {
        // Check if cell already has a location_id
        const { data: existing } = await supabase
          .from("cell_properties")
          .select("location_id")
          .eq("cell_id", cell.cell_id)
          .maybeSingle();

        if (existing?.location_id) {
          results.push({
            cell_id: cell.cell_id,
            status: "already_enriched",
            location_id: existing.location_id,
          });
          continue; // Skip Nominatim — no delay needed
        }

        // Rate-limit: delay before every Nominatim call except the first
        if (nominatimCallCount > 0) {
          await delay(NOMINATIM_DELAY_MS);
        }

        const nominatim = await reverseGeocode(cell.lat, cell.lon);
        nominatimCallCount++;

        const nodes = buildHierarchy(nominatim.address, nominatim.osm_id);

        if (nodes.length === 0) {
          results.push({
            cell_id: cell.cell_id,
            status: "no_location_data",
          });
          continue;
        }

        // Upsert all location nodes (idempotent — same ID = no-op)
        for (const node of nodes) {
          await supabase.from("location_nodes").upsert(
            {
              id: node.id,
              name: node.name,
              admin_level: node.admin_level,
              parent_id: node.parent_id,
              osm_id: node.osm_id,
            },
            { onConflict: "id" },
          );
        }

        const deepestNode = nodes[nodes.length - 1];

        // Update cell_properties with the deepest location_id
        const { error: updateError } = await supabase
          .from("cell_properties")
          .update({ location_id: deepestNode.id })
          .eq("cell_id", cell.cell_id);

        if (updateError) {
          console.error(
            `Failed to update cell location_id for ${cell.cell_id}:`,
            updateError,
          );
          // Non-fatal — nodes are persisted, cell will catch up
        }

        results.push({
          cell_id: cell.cell_id,
          status: "enriched",
          location_id: deepestNode.id,
          hierarchy: nodes.map((n) => ({
            id: n.id,
            name: n.name,
            level: n.admin_level,
          })),
        });
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        console.error(`Error processing cell ${cell.cell_id}:`, message);
        errors.push({ cell_id: cell.cell_id, error: message });
        // Continue processing remaining cells
      }
    }

    return new Response(
      JSON.stringify({ results, errors }),
      { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
