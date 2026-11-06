-- What each strategy holds: cost, number of strips, shortest and longest strip,
-- and its Macaulay duration (for strips, the cost-weighted average maturity).
-- Compare every duration with the promise's duration from liability_profile.sql.
SELECT
  strategy,
  COUNT(*)                          AS strips_held,
  MIN(maturity)                     AS shortest,
  MAX(maturity)                     AS longest,
  ROUND(SUM(cost), 2)               AS cost,
  SUM(maturity * cost) / SUM(cost)  AS mac_duration
FROM holding
WHERE face > 0
GROUP BY strategy
ORDER BY cost DESC;
