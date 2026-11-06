-- The 5th percentile of surplus for each strategy (a 95% value-at-risk view),
-- found by ranking each strategy's scenarios from worst to best.
WITH ranked AS (
  SELECT
    strategy,
    surplus,
    ROW_NUMBER() OVER (PARTITION BY strategy ORDER BY surplus) AS rnk,
    COUNT(*)     OVER (PARTITION BY strategy)                   AS n
  FROM scenario_result
)
SELECT
  strategy,
  ROUND(surplus / 1e6, 2) AS p5_surplus_m
FROM ranked
WHERE rnk = CAST(0.05 * n AS INTEGER)
ORDER BY p5_surplus_m DESC;
