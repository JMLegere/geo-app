DROP FUNCTION IF EXISTS get_hierarchy_scope_summary(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS get_hierarchy_child_summaries_with_rank(UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION get_hierarchy_scope_summary(
  p_user_id UUID,
  p_scope_level TEXT,
  p_scope_id TEXT DEFAULT NULL
)
RETURNS TABLE (
  id TEXT,
  name TEXT,
  level TEXT,
  cells_visited BIGINT,
  cells_total BIGINT,
  progress_percent DOUBLE PRECISION,
  rank BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_scope_level NOT IN ('cell', 'district', 'city', 'state', 'country', 'world') THEN
    RAISE EXCEPTION 'Unsupported scope level: %', p_scope_level;
  END IF;

  RETURN QUERY
  WITH cell_hierarchy AS (
    SELECT
      cp.cell_id,
      d.id AS district_id,
      COALESCE(c_from_d.id, c_direct.id) AS city_id,
      COALESCE(s_from_c.id, s_direct.id) AS state_id,
      COALESCE(co_from_s.id, co_direct.id) AS country_id
    FROM cell_properties cp
    LEFT JOIN districts d ON d.id = cp.location_id
    LEFT JOIN cities c_from_d ON c_from_d.id = d.city_id
    LEFT JOIN cities c_direct ON c_direct.id = cp.location_id
    LEFT JOIN states s_from_c ON s_from_c.id = COALESCE(c_from_d.state_id, c_direct.state_id)
    LEFT JOIN states s_direct ON s_direct.id = cp.location_id
    LEFT JOIN countries co_from_s ON co_from_s.id = COALESCE(s_from_c.country_id, s_direct.country_id)
    LEFT JOIN countries co_direct ON co_direct.id = cp.location_id
  ),
  scope_cells AS (
    SELECT DISTINCT ch.cell_id
    FROM cell_hierarchy ch
    WHERE
      (p_scope_level = 'world') OR
      (p_scope_level = 'country' AND ch.country_id = p_scope_id) OR
      (p_scope_level = 'state' AND ch.state_id = p_scope_id) OR
      (p_scope_level = 'city' AND ch.city_id = p_scope_id) OR
      (p_scope_level = 'district' AND ch.district_id = p_scope_id) OR
      (p_scope_level = 'cell' AND ch.cell_id = p_scope_id)
  ),
  scope_meta AS (
    SELECT scope.id, scope.name, scope.level, scope.cells_total
    FROM (
      SELECT d.id, d.name, 'district'::TEXT AS level, COALESCE(d.cells_total, 0)::BIGINT AS cells_total
      FROM districts d
      WHERE p_scope_level = 'district' AND d.id = p_scope_id

      UNION ALL

      SELECT c.id, c.name, 'city'::TEXT AS level, COALESCE(c.cells_total, 0)::BIGINT AS cells_total
      FROM cities c
      WHERE p_scope_level = 'city' AND c.id = p_scope_id

      UNION ALL

      SELECT s.id, s.name, 'state'::TEXT AS level, COALESCE(s.cells_total, 0)::BIGINT AS cells_total
      FROM states s
      WHERE p_scope_level = 'state' AND s.id = p_scope_id

      UNION ALL

      SELECT co.id, co.name, 'country'::TEXT AS level, COALESCE(co.cells_total, 0)::BIGINT AS cells_total
      FROM countries co
      WHERE p_scope_level = 'country' AND co.id = p_scope_id

      UNION ALL

      SELECT 'world'::TEXT AS id, 'World'::TEXT AS name, 'world'::TEXT AS level, COALESCE(SUM(countries.cells_total), 0)::BIGINT AS cells_total
      FROM countries
      WHERE p_scope_level = 'world'

      UNION ALL

      SELECT cp.cell_id AS id, cp.cell_id AS name, 'cell'::TEXT AS level, 1::BIGINT AS cells_total
      FROM cell_properties cp
      WHERE p_scope_level = 'cell' AND cp.cell_id = p_scope_id
    ) AS scope
    LIMIT 1
  ),
  user_scope_counts AS (
    SELECT
      v.user_id,
      COUNT(DISTINCT v.cell_id)::BIGINT AS cells_visited
    FROM v3_cell_visits v
    JOIN scope_cells sc ON sc.cell_id = v.cell_id
    GROUP BY v.user_id
  ),
  ranked_scope_counts AS (
    SELECT
      usc.user_id,
      usc.cells_visited,
      RANK() OVER (ORDER BY usc.cells_visited DESC, usc.user_id) AS rank
    FROM user_scope_counts usc
  ),
  current_user_scope AS (
    SELECT rsc.cells_visited, rsc.rank
    FROM ranked_scope_counts rsc
    WHERE rsc.user_id = p_user_id
    LIMIT 1
  )
  SELECT
    sm.id,
    sm.name,
    sm.level,
    COALESCE(cus.cells_visited, 0)::BIGINT AS cells_visited,
    sm.cells_total,
    CASE
      WHEN sm.cells_total > 0 THEN (COALESCE(cus.cells_visited, 0)::DOUBLE PRECISION / sm.cells_total::DOUBLE PRECISION) * 100
      ELSE 0
    END AS progress_percent,
    COALESCE(cus.rank, 0)::BIGINT AS rank
  FROM scope_meta sm
  LEFT JOIN current_user_scope cus ON TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION get_hierarchy_child_summaries_with_rank(
  p_user_id UUID,
  p_scope_level TEXT,
  p_scope_id TEXT DEFAULT NULL
)
RETURNS TABLE (
  id TEXT,
  name TEXT,
  level TEXT,
  cells_visited BIGINT,
  cells_total BIGINT,
  progress_percent DOUBLE PRECISION,
  rank BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_scope_level NOT IN ('district', 'city', 'state', 'country', 'world') THEN
    RAISE EXCEPTION 'Unsupported scope level for child summaries: %', p_scope_level;
  END IF;

  RETURN QUERY
  WITH cell_hierarchy AS (
    SELECT
      cp.cell_id,
      d.id AS district_id,
      COALESCE(c_from_d.id, c_direct.id) AS city_id,
      COALESCE(s_from_c.id, s_direct.id) AS state_id,
      COALESCE(co_from_s.id, co_direct.id) AS country_id
    FROM cell_properties cp
    LEFT JOIN districts d ON d.id = cp.location_id
    LEFT JOIN cities c_from_d ON c_from_d.id = d.city_id
    LEFT JOIN cities c_direct ON c_direct.id = cp.location_id
    LEFT JOIN states s_from_c ON s_from_c.id = COALESCE(c_from_d.state_id, c_direct.state_id)
    LEFT JOIN states s_direct ON s_direct.id = cp.location_id
    LEFT JOIN countries co_from_s ON co_from_s.id = COALESCE(s_from_c.country_id, s_direct.country_id)
    LEFT JOIN countries co_direct ON co_direct.id = cp.location_id
  ),
  base_children AS (
    SELECT co.id, co.name, 'country'::TEXT AS level, COALESCE(co.cells_total, 0)::BIGINT AS cells_total
    FROM countries co
    WHERE p_scope_level = 'world'

    UNION ALL

    SELECT s.id, s.name, 'state'::TEXT AS level, COALESCE(s.cells_total, 0)::BIGINT AS cells_total
    FROM states s
    WHERE p_scope_level = 'country' AND s.country_id = p_scope_id

    UNION ALL

    SELECT c.id, c.name, 'city'::TEXT AS level, COALESCE(c.cells_total, 0)::BIGINT AS cells_total
    FROM cities c
    WHERE p_scope_level = 'state' AND c.state_id = p_scope_id

    UNION ALL

    SELECT d.id, d.name, 'district'::TEXT AS level, COALESCE(d.cells_total, 0)::BIGINT AS cells_total
    FROM districts d
    WHERE p_scope_level = 'city' AND d.city_id = p_scope_id

    UNION ALL

    SELECT ch.cell_id AS id, ch.cell_id AS name, 'cell'::TEXT AS level, 1::BIGINT AS cells_total
    FROM cell_hierarchy ch
    WHERE p_scope_level = 'district' AND ch.district_id = p_scope_id
  ),
  child_cells AS (
    SELECT ch.country_id AS child_id, ch.cell_id
    FROM cell_hierarchy ch
    WHERE p_scope_level = 'world'

    UNION ALL

    SELECT ch.state_id AS child_id, ch.cell_id
    FROM cell_hierarchy ch
    WHERE p_scope_level = 'country' AND ch.country_id = p_scope_id

    UNION ALL

    SELECT ch.city_id AS child_id, ch.cell_id
    FROM cell_hierarchy ch
    WHERE p_scope_level = 'state' AND ch.state_id = p_scope_id

    UNION ALL

    SELECT ch.district_id AS child_id, ch.cell_id
    FROM cell_hierarchy ch
    WHERE p_scope_level = 'city' AND ch.city_id = p_scope_id

    UNION ALL

    SELECT ch.cell_id AS child_id, ch.cell_id
    FROM cell_hierarchy ch
    WHERE p_scope_level = 'district' AND ch.district_id = p_scope_id
  ),
  user_child_counts AS (
    SELECT
      cc.child_id,
      v.user_id,
      COUNT(DISTINCT v.cell_id)::BIGINT AS cells_visited
    FROM child_cells cc
    JOIN v3_cell_visits v ON v.cell_id = cc.cell_id
    GROUP BY cc.child_id, v.user_id
  ),
  ranked_child_counts AS (
    SELECT
      ucc.child_id,
      ucc.user_id,
      ucc.cells_visited,
      RANK() OVER (PARTITION BY ucc.child_id ORDER BY ucc.cells_visited DESC, ucc.user_id) AS rank
    FROM user_child_counts ucc
  ),
  current_user_counts AS (
    SELECT rcc.child_id, rcc.cells_visited, rcc.rank
    FROM ranked_child_counts rcc
    WHERE rcc.user_id = p_user_id
  )
  SELECT
    bc.id,
    bc.name,
    bc.level,
    COALESCE(cuc.cells_visited, 0)::BIGINT AS cells_visited,
    bc.cells_total,
    CASE
      WHEN bc.cells_total > 0 THEN (COALESCE(cuc.cells_visited, 0)::DOUBLE PRECISION / bc.cells_total::DOUBLE PRECISION) * 100
      ELSE 0
    END AS progress_percent,
    COALESCE(cuc.rank, 0)::BIGINT AS rank
  FROM base_children bc
  LEFT JOIN current_user_counts cuc ON cuc.child_id = bc.id
  ORDER BY bc.name ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_hierarchy_scope_summary(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_hierarchy_scope_summary(UUID, TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION get_hierarchy_child_summaries_with_rank(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_hierarchy_child_summaries_with_rank(UUID, TEXT, TEXT) TO service_role;
