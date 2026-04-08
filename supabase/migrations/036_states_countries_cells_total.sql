-- Add cells_total prerequisites for upper hierarchy levels.
-- Required so state/country map experience can show complete cell totals.

ALTER TABLE states
ADD COLUMN IF NOT EXISTS cells_total INTEGER NOT NULL DEFAULT 0;

ALTER TABLE countries
ADD COLUMN IF NOT EXISTS cells_total INTEGER NOT NULL DEFAULT 0;

UPDATE states AS s
SET cells_total = st.total_cells
FROM (
  SELECT
    c.state_id,
    COALESCE(SUM(COALESCE(c.cells_total, 0)), 0)::INTEGER AS total_cells
  FROM cities AS c
  GROUP BY c.state_id
) AS st
WHERE s.id = st.state_id;

UPDATE countries AS c
SET cells_total = ct.total_cells
FROM (
  SELECT
    s.country_id,
    COALESCE(SUM(COALESCE(s.cells_total, 0)), 0)::INTEGER AS total_cells
  FROM states AS s
  GROUP BY s.country_id
) AS ct
WHERE c.id = ct.country_id;

CREATE INDEX IF NOT EXISTS idx_states_cells_total ON states(cells_total);
CREATE INDEX IF NOT EXISTS idx_countries_cells_total ON countries(cells_total);
