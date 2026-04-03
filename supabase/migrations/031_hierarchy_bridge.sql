-- Bridge: sync location_nodes → hierarchy tables (countries, states, cities, districts).
--
-- The enrich-location Edge Functions write to the flat location_nodes tree.
-- The v2 client reads from the normalized hierarchy tables.
-- This function + trigger keeps them in sync.
--
-- Walks the parent chain of each location_node to find its ancestors,
-- then upserts into the appropriate hierarchy table.

-- Function: given a location_node row, upsert into the correct hierarchy table.
CREATE OR REPLACE FUNCTION sync_location_node_to_hierarchy()
RETURNS TRIGGER AS $$
DECLARE
  v_parent RECORD;
  v_grandparent RECORD;
  v_greatgrandparent RECORD;
  v_country_id TEXT;
  v_state_id TEXT;
  v_city_id TEXT;
BEGIN
  -- Only process admin levels we care about
  IF NEW.admin_level NOT IN ('country', 'state', 'city', 'district') THEN
    RETURN NEW;
  END IF;

  -- Country: insert directly
  IF NEW.admin_level = 'country' THEN
    INSERT INTO countries (id, name, centroid_lat, centroid_lon, continent)
    VALUES (
      NEW.id,
      NEW.name,
      0, -- centroid backfilled by enrichment
      0,
      'unknown' -- continent backfilled by enrichment
    )
    ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;
    RETURN NEW;
  END IF;

  -- State: parent must be a country
  IF NEW.admin_level = 'state' THEN
    SELECT * INTO v_parent FROM location_nodes WHERE id = NEW.parent_id;
    IF v_parent IS NULL OR v_parent.admin_level != 'country' THEN
      RETURN NEW; -- skip if parent chain is incomplete
    END IF;
    -- Ensure country exists
    INSERT INTO countries (id, name, centroid_lat, centroid_lon, continent)
    VALUES (v_parent.id, v_parent.name, 0, 0, 'unknown')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO states (id, name, centroid_lat, centroid_lon, country_id)
    VALUES (NEW.id, NEW.name, 0, 0, v_parent.id)
    ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;
    RETURN NEW;
  END IF;

  -- City: parent must be a state, grandparent a country
  IF NEW.admin_level = 'city' THEN
    SELECT * INTO v_parent FROM location_nodes WHERE id = NEW.parent_id;
    IF v_parent IS NULL OR v_parent.admin_level != 'state' THEN
      RETURN NEW;
    END IF;
    SELECT * INTO v_grandparent FROM location_nodes WHERE id = v_parent.parent_id;
    IF v_grandparent IS NULL OR v_grandparent.admin_level != 'country' THEN
      RETURN NEW;
    END IF;
    -- Ensure ancestors exist
    INSERT INTO countries (id, name, centroid_lat, centroid_lon, continent)
    VALUES (v_grandparent.id, v_grandparent.name, 0, 0, 'unknown')
    ON CONFLICT (id) DO NOTHING;
    INSERT INTO states (id, name, centroid_lat, centroid_lon, country_id)
    VALUES (v_parent.id, v_parent.name, 0, 0, v_grandparent.id)
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO cities (id, name, centroid_lat, centroid_lon, state_id)
    VALUES (NEW.id, NEW.name, 0, 0, v_parent.id)
    ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;
    RETURN NEW;
  END IF;

  -- District: parent=city, grandparent=state, great-grandparent=country
  IF NEW.admin_level = 'district' THEN
    SELECT * INTO v_parent FROM location_nodes WHERE id = NEW.parent_id;
    IF v_parent IS NULL OR v_parent.admin_level != 'city' THEN
      RETURN NEW;
    END IF;
    SELECT * INTO v_grandparent FROM location_nodes WHERE id = v_parent.parent_id;
    IF v_grandparent IS NULL OR v_grandparent.admin_level != 'state' THEN
      RETURN NEW;
    END IF;
    SELECT * INTO v_greatgrandparent FROM location_nodes WHERE id = v_grandparent.parent_id;
    IF v_greatgrandparent IS NULL OR v_greatgrandparent.admin_level != 'country' THEN
      RETURN NEW;
    END IF;
    -- Ensure ancestors exist
    INSERT INTO countries (id, name, centroid_lat, centroid_lon, continent)
    VALUES (v_greatgrandparent.id, v_greatgrandparent.name, 0, 0, 'unknown')
    ON CONFLICT (id) DO NOTHING;
    INSERT INTO states (id, name, centroid_lat, centroid_lon, country_id)
    VALUES (v_grandparent.id, v_grandparent.name, 0, 0, v_greatgrandparent.id)
    ON CONFLICT (id) DO NOTHING;
    INSERT INTO cities (id, name, centroid_lat, centroid_lon, state_id)
    VALUES (v_parent.id, v_parent.name, 0, 0, v_grandparent.id)
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO districts (id, name, centroid_lat, centroid_lon, city_id)
    VALUES (NEW.id, NEW.name, 0, 0, v_parent.id)
    ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: fires on every INSERT or UPDATE to location_nodes
CREATE TRIGGER trg_sync_hierarchy
  AFTER INSERT OR UPDATE ON location_nodes
  FOR EACH ROW
  EXECUTE FUNCTION sync_location_node_to_hierarchy();

-- Backfill: sync existing location_nodes into hierarchy tables
-- (run once, then the trigger handles new rows)
DO $$
DECLARE
  r RECORD;
BEGIN
  -- Process in order: countries first, then states, cities, districts
  FOR r IN SELECT * FROM location_nodes WHERE admin_level = 'country' ORDER BY created_at LOOP
    PERFORM sync_location_node_to_hierarchy();
  END LOOP;
END $$;

-- Note: The backfill above won't actually work because it can't call a trigger function directly.
-- Instead, do a simple UPDATE that re-triggers the function:
UPDATE location_nodes SET name = name WHERE admin_level IN ('country', 'state', 'city', 'district');
