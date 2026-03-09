#!/usr/bin/env python3
"""
Fix 434 species that have habitat names as their commonName.

Step 1: Call generate-common-names Edge Function to get real names via Groq LLM
Step 2: Patch species_data.json with corrected names
Step 3: Save a mapping file for verification

Usage:
  python3 scripts/fix_common_names.py
"""

import json
import time
import sys
import urllib.request
import urllib.error

SUPABASE_URL = "https://bfaczcsrpfcbijoaeckb.supabase.co"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJmYWN6Y3NycGZjYmlqb2FlY2tiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI1NzE3ODYsImV4cCI6MjA4ODE0Nzc4Nn0.hyjp1NRiteavWfBnch1LpRARtiN5lvpP0PztbRwqPJ8"
SPECIES_JSON = "assets/species_data.json"
MAPPING_FILE = "scripts/common_name_fixes.json"
BATCH_SIZE = 30
HABITATS = {"Forest", "Plains", "Freshwater", "Saltwater", "Swamp", "Mountain", "Desert"}


def call_edge_function(species_batch):
    url = f"{SUPABASE_URL}/functions/v1/generate-common-names"
    payload = json.dumps({"species": species_batch}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {ANON_KEY}",
            "apikey": ANON_KEY,
        },
        method="POST",
    )
    resp = urllib.request.urlopen(req, timeout=120)
    return json.loads(resp.read().decode("utf-8"))


def main():
    with open(SPECIES_JSON) as f:
        data = json.load(f)

    affected = [
        sp for sp in data if sp.get("commonName") in HABITATS
    ]
    print(f"Found {len(affected)} species with habitat names as commonName")

    name_map = {}
    batches = [affected[i:i + BATCH_SIZE] for i in range(0, len(affected), BATCH_SIZE)]
    print(f"Processing {len(batches)} batches of up to {BATCH_SIZE}...")

    for i, batch in enumerate(batches):
        batch_input = [
            {"scientific_name": sp["scientificName"], "taxonomic_class": sp["taxonomicClass"]}
            for sp in batch
        ]

        retries = 0
        while retries < 3:
            try:
                print(f"  Batch {i + 1}/{len(batches)} ({len(batch)} species)...", end=" ", flush=True)
                result = call_edge_function(batch_input)

                if "error" in result:
                    print(f"ERROR: {result['error']}")
                    retries += 1
                    wait = 65 if "429" in str(result.get("error", "")) else 5
                    print(f"    Retrying in {wait}s...")
                    time.sleep(wait)
                    continue

                results = result.get("results", [])
                for r in results:
                    sci_name = r.get("scientific_name", "")
                    common_name = r.get("common_name", "")
                    if sci_name and common_name:
                        name_map[sci_name] = common_name

                print(f"OK ({len(results)} names)")
                break

            except urllib.error.HTTPError as e:
                body = e.read().decode("utf-8", errors="replace")
                print(f"HTTP {e.code}: {body}")
                retries += 1
                if e.code == 429:
                    retry_after = int(e.headers.get("Retry-After", "65"))
                    print(f"    Rate limited. Waiting {retry_after}s...")
                    time.sleep(retry_after)
                elif retries < 3:
                    print(f"    Retrying in 5s...")
                    time.sleep(5)
            except Exception as e:
                print(f"Error: {e}")
                retries += 1
                if retries < 3:
                    time.sleep(5)

        if retries >= 3:
            print(f"  FAILED batch {i + 1} after 3 retries. Continuing...")

        time.sleep(2)

    print(f"\nGenerated {len(name_map)} common names out of {len(affected)} species")

    missing = [sp["scientificName"] for sp in affected if sp["scientificName"] not in name_map]
    if missing:
        print(f"WARNING: {len(missing)} species missing names: {missing[:5]}...")

    with open(MAPPING_FILE, "w") as f:
        json.dump(name_map, f, indent=2)
    print(f"Saved name mapping to {MAPPING_FILE}")

    patched = 0
    for sp in data:
        sci_name = sp.get("scientificName")
        if sci_name in name_map:
            old = sp["commonName"]
            sp["commonName"] = name_map[sci_name]
            patched += 1

    with open(SPECIES_JSON, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    print(f"Patched {patched} species in {SPECIES_JSON}")

    print("\nSample fixes:")
    for sci_name, common_name in list(name_map.items())[:10]:
        old_name = next(
            (sp["commonName"] for sp in affected if sp["scientificName"] == sci_name),
            "?",
        )
        print(f"  {sci_name}: '{old_name}' -> '{common_name}'")


if __name__ == "__main__":
    main()
