-- The three worst shocks for each strategy, and what the curve did in each.
-- A negative slope means long rates fell relative to short rates (a flattening).
WITH ranked AS (
  SELECT
    r.strategy,
    r.scenario,
    s.level,
    s.slope,
    r.surplus,
    ROW_NUMBER() OVER (PARTITION BY r.strategy ORDER BY r.surplus) AS rnk
  FROM scenario_result AS r
  JOIN scenario AS s ON s.scenario = r.scenario
)
SELECT
  strategy,
  rnk                        AS worst_rank,
  scenario,
  ROUND(10000 * level)       AS level_bp,
  ROUND(10000 * slope)       AS slope_bp,
  ROUND(surplus / 1e6, 2)    AS surplus_m
FROM ranked
WHERE rnk <= 3
ORDER BY strategy, rnk;
