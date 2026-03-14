import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// --- Types ---

interface BoundaryResult {
  admin_level: string;
  name: string;
  osm_id: number | null;
  geometry_json: Record<string, unknown> | null;
}

interface NominatimPolygonResponse {
  place_id: number;
  osm_type: string;
  osm_id: number;
  name: string;
  display_name: string;
  address: Record<string, string>;
  geojson?: Record<string, unknown>;
}

const BOUNDARY_LEVELS = [
  { admin_level: "country", zoom: 3 },
  { admin_level: "state", zoom: 5 },
  { admin_level: "city", zoom: 8 },
  { admin_level: "district", zoom: 10 },
] as const;

// --- Nominatim ---

const NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse";
const USER_AGENT = "EarthNova/1.0 (https://earthnova.app)";
const RATE_LIMIT_MS = 1200; // 1.2s between Nominatim calls

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function reverseGeocode(
  lat: number,
  lon: number,
): Promise<{ address: Record<string, string>; osm_id: number }> {
  const url = new URL(NOMINATIM_URL);
  url.searchParams.set("lat", lat.toString());
  url.searchParams.set("lon", lon.toString());
  url.searchParams.set("format", "jsonv2");
  url.searchParams.set("addressdetails", "1");
  url.searchParams.set("zoom", "18");

  const resp = await fetch(url.toString(), {
    headers: { "User-Agent": USER_AGENT },
  });

  if (!resp.ok) {
    throw new Error(`Nominatim ${resp.status}: ${await resp.text()}`);
  }

  return resp.json();
}

async function reverseGeocodeWithPolygon(
  lat: number,
  lon: number,
  zoom: number,
): Promise<NominatimPolygonResponse> {
  const url = new URL(NOMINATIM_URL);
  url.searchParams.set("lat", lat.toString());
  url.searchParams.set("lon", lon.toString());
  url.searchParams.set("format", "jsonv2");
  url.searchParams.set("polygon_geojson", "1");
  url.searchParams.set("polygon_threshold", "0.001");
  url.searchParams.set("zoom", zoom.toString());

  const resp = await fetch(url.toString(), {
    headers: { "User-Agent": USER_AGENT },
  });

  if (!resp.ok) {
    throw new Error(`Nominatim ${resp.status}: ${await resp.text()}`);
  }

  return resp.json();
}

// --- Hierarchy ID builder (matches enrich-location pattern) ---

function makeId(level: string, name: string): string {
  const slug = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_|_$/g, "");
  return `${level}_${slug}`;
}

function buildNodeIds(
  address: Record<string, string>,
): Record<string, string> {
  const result: Record<string, string> = {};
  const countryCode = address.country_code ?? "";

  const countryName = address.country;
  if (countryName) {
    result.country = makeId("country", countryName);
  }

  const stateName = address.state ?? address.province;
  if (stateName && countryCode) {
    result.state = makeId("state", `${countryCode}_${stateName}`);
  }

  const cityName = address.city ?? address.town ?? address.village;
  if (cityName && countryCode) {
    result.city = makeId("city", `${countryCode}_${cityName}`);
  }

  const districtName =
    address.suburb ?? address.neighbourhood ?? address.quarter;
  if (districtName && countryCode) {
    result.district = makeId("district", `${countryCode}_${districtName}`);
  }

  return result;
}

// --- Auth (matches enrich-location pattern) ---

async function validateAuth(req: Request): Promise<Response | null> {
  const authHeader = req.headers.get("authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({ error: "Missing or invalid authorization header" }),
      {
        status: 401,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      },
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
      {
        status: 401,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      },
    );
  }
  return null;
}

// --- Main handler ---

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  const authResponse = await validateAuth(req);
  if (authResponse) return authResponse;

  try {
    const body = await req.json();
    const { lat, lon } = body;

    if (typeof lat !== "number" || typeof lon !== "number") {
      return new Response(
        JSON.stringify({ error: "Missing required fields: lat, lon" }),
        {
          status: 400,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      return new Response(
        JSON.stringify({ error: "Invalid coordinates" }),
        {
          status: 400,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // ---------------------------------------------------------------
    // Step 1: Initial reverse geocode (no polygon) to identify hierarchy
    // ---------------------------------------------------------------
    let nominatimCallCount = 0;
    const nominatim = await reverseGeocode(lat, lon);
    nominatimCallCount++;

    const nodeIds = buildNodeIds(nominatim.address);
    console.log(
      `resolve-admin-boundaries: hierarchy for (${lat}, ${lon}):`,
      JSON.stringify(nodeIds),
    );

    // ---------------------------------------------------------------
    // Step 2: Check cache for each admin level
    // ---------------------------------------------------------------
    const boundaries: BoundaryResult[] = [];
    const uncached: Array<{
      admin_level: string;
      zoom: number;
      nodeId: string;
    }> = [];

    // Track whether geometry_json column exists in the schema.
    // If the first query fails because the column is missing, skip all
    // subsequent cache reads/writes and treat everything as a cache miss.
    let geometryColumnExists = true;

    for (const { admin_level, zoom } of BOUNDARY_LEVELS) {
      const nodeId = nodeIds[admin_level];
      if (!nodeId) continue;

      if (!geometryColumnExists) {
        uncached.push({ admin_level, zoom, nodeId });
        continue;
      }

      try {
        const { data, error } = await supabase
          .from("location_nodes")
          .select("id, name, osm_id, geometry_json")
          .eq("id", nodeId)
          .maybeSingle();

        if (error) {
          const msg = error.message ?? "";
          if (
            msg.includes("geometry_json") ||
            error.code === "42703" ||
            msg.includes("column") 
          ) {
            console.log(
              "geometry_json column does not exist yet — treating all as cache miss",
            );
            geometryColumnExists = false;
          } else {
            console.error(`Cache check error for ${admin_level}:`, error);
          }
          uncached.push({ admin_level, zoom, nodeId });
        } else if (data?.geometry_json) {
          console.log(`Cache HIT: ${admin_level} (${nodeId})`);
          boundaries.push({
            admin_level,
            name: data.name,
            osm_id: data.osm_id,
            geometry_json: data.geometry_json as Record<string, unknown>,
          });
        } else {
          console.log(`Cache MISS: ${admin_level} (${nodeId})`);
          uncached.push({ admin_level, zoom, nodeId });
        }
      } catch (e) {
        console.error(
          `Unexpected error checking cache for ${admin_level}:`,
          e,
        );
        uncached.push({ admin_level, zoom, nodeId });
      }
    }

    // ---------------------------------------------------------------
    // Step 3: Fetch uncached polygons from Nominatim
    // ---------------------------------------------------------------
    for (const { admin_level, zoom, nodeId } of uncached) {
      if (nominatimCallCount > 0) {
        await delay(RATE_LIMIT_MS);
      }

      try {
        const result = await reverseGeocodeWithPolygon(lat, lon, zoom);
        nominatimCallCount++;
        console.log(
          `Nominatim CALL: ${admin_level} (zoom=${zoom}) → osm_id=${result.osm_id}, has_polygon=${!!result.geojson}`,
        );

        const geometryJson = result.geojson ?? null;

        if (geometryJson) {
          if (geometryColumnExists) {
            try {
              const { error: updateError } = await supabase
                .from("location_nodes")
                .update({
                  geometry_json: geometryJson,
                  osm_id: result.osm_id,
                })
                .eq("id", nodeId);

              if (updateError) {
                const msg = updateError.message ?? "";
                if (
                  msg.includes("geometry_json") ||
                  updateError.code === "42703" ||
                  msg.includes("column")
                ) {
                  console.log(
                    "geometry_json column does not exist — skipping cache writes",
                  );
                  geometryColumnExists = false;
                } else {
                  console.error(
                    `Failed to cache ${admin_level} geometry:`,
                    updateError,
                  );
                }
              }
            } catch (e) {
              console.error(
                `Unexpected error writing cache for ${admin_level}:`,
                e,
              );
            }
          }

          boundaries.push({
            admin_level,
            name: result.name || result.display_name,
            osm_id: result.osm_id,
            geometry_json: geometryJson,
          });
        } else {
          console.log(
            `No polygon returned for ${admin_level} at zoom=${zoom}`,
          );
        }
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        console.error(`Failed to fetch ${admin_level} boundary: ${message}`);
      }
    }

    // ---------------------------------------------------------------
    // Step 4: Return results
    // ---------------------------------------------------------------
    const cacheHits = BOUNDARY_LEVELS.length - uncached.length;
    console.log(
      `resolve-admin-boundaries complete: ` +
        `${boundaries.length} boundaries, ` +
        `${nominatimCallCount} Nominatim calls, ` +
        `${cacheHits} cache hits`,
    );

    return new Response(JSON.stringify({ boundaries }), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`resolve-admin-boundaries error: ${message}`);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
