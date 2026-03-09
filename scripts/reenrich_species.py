#!/usr/bin/env python3
"""
Re-enrich 434 species that had habitat names as commonName.

Calls the enrich-species Edge Function with force:true for each species,
using the corrected common names from species_data.json.
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
RESULTS_FILE = "scripts/reenrichment_results.json"


def parse_retry_seconds(text):
    import re
    m = re.search(r'(\d+)m(\d+(?:\.\d+)?)s', str(text))
    if m:
        return int(m.group(1)) * 60 + int(float(m.group(2))) + 5
    m = re.search(r'(\d+(?:\.\d+)?)s', str(text))
    if m:
        return int(float(m.group(1))) + 5
    return 120


def make_definition_id(scientific_name):
    return f"fauna_{scientific_name.lower().replace(' ', '_')}"


def call_enrich(definition_id, scientific_name, common_name, taxonomic_class):
    url = f"{SUPABASE_URL}/functions/v1/enrich-species"
    payload = json.dumps({
        "definition_id": definition_id,
        "scientific_name": scientific_name,
        "common_name": common_name,
        "taxonomic_class": taxonomic_class,
        "force": True,
    }).encode("utf-8")
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
    resp = urllib.request.urlopen(req, timeout=60)
    return json.loads(resp.read().decode("utf-8"))


def main():
    with open(SPECIES_JSON) as f:
        all_species = json.load(f)

    with open(MAPPING_FILE) as f:
        fixes = json.load(f)

    species_by_name = {sp["scientificName"]: sp for sp in all_species}
    to_enrich = []
    for sci_name in fixes:
        sp = species_by_name.get(sci_name)
        if sp:
            to_enrich.append(sp)

    print(f"Re-enriching {len(to_enrich)} species with corrected common names")

    already_done = set()
    try:
        with open(RESULTS_FILE) as f:
            prev = json.load(f)
            if "done_species" in prev:
                already_done = set(prev["done_species"])
                print(f"Resuming: {len(already_done)} already done")
    except (FileNotFoundError, json.JSONDecodeError):
        pass

    results = {}
    errors = []
    for i, sp in enumerate(to_enrich):
        if sp["scientificName"] in already_done:
            results[sp["scientificName"]] = {"skipped": True}
            continue
        sci_name = sp["scientificName"]
        common_name = sp["commonName"]
        definition_id = make_definition_id(sci_name)
        taxonomic_class = sp["taxonomicClass"]

        success = False
        hard_failures = 0
        while not success and hard_failures < 3:
            try:
                print(f"  [{i + 1}/{len(to_enrich)}] {sci_name}...", end=" ", flush=True)

                result = call_enrich(definition_id, sci_name, common_name, taxonomic_class)

                if "error" in result and "429" in str(result.get("error", "")):
                    wait = parse_retry_seconds(result["error"])
                    print(f"rate limited, sleeping {wait}s")
                    time.sleep(wait)
                    continue
                elif "error" in result:
                    print(f"ERROR: {result['error']}")
                    errors.append({"species": sci_name, "error": result["error"]})
                    hard_failures += 1
                    time.sleep(5)
                    continue

                results[sci_name] = result
                print(f"OK ({result.get('animal_class', '?')})")
                success = True

            except urllib.error.HTTPError as e:
                body = e.read().decode("utf-8", errors="replace")
                if e.code == 429:
                    wait = parse_retry_seconds(body)
                    hhdr = e.headers.get("Retry-After")
                    if hhdr:
                        try:
                            wait = max(wait, int(float(hhdr)))
                        except ValueError:
                            pass
                    print(f"rate limited, sleeping {wait}s")
                    time.sleep(wait)
                else:
                    print(f"HTTP {e.code}")
                    hard_failures += 1
                    time.sleep(5)
            except Exception as e:
                print(f"error: {e}")
                hard_failures += 1
                time.sleep(5)

        if not success:
            errors.append({"species": sci_name, "error": "max retries exceeded"})

        if (i + 1) % 50 == 0:
            done_species = [k for k, v in results.items() if not v.get("skipped")]
            with open(RESULTS_FILE, "w") as f:
                json.dump({"enriched": len(done_species), "errors": errors, "done_species": done_species, "sample": dict(list(results.items())[:5])}, f, indent=2)
            print(f"  [checkpoint] saved {len(done_species)} results")

        time.sleep(2.5)

    print(f"\n\nResults: {len(results)} enriched, {len(errors)} errors")

    done_species = [k for k, v in results.items() if not v.get("skipped")]
    with open(RESULTS_FILE, "w") as f:
        json.dump({"enriched": len(done_species), "errors": errors, "done_species": done_species, "sample": dict(list(results.items())[:5])}, f, indent=2)
    print(f"Saved results to {RESULTS_FILE}")

    if results:
        print("\nSample enrichment results:")
        for sci_name, enrichment in list(results.items())[:5]:
            print(f"  {sci_name}: class={enrichment.get('animal_class')}, "
                  f"food={enrichment.get('food_preference')}, "
                  f"climate={enrichment.get('climate')}, "
                  f"stats={enrichment.get('brawn')}/{enrichment.get('wit')}/{enrichment.get('speed')}")


if __name__ == "__main__":
    main()
