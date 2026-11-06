-- How each strategy fares across the random shocks:
-- average and worst surplus, and how often the shock turns surplus negative.
-- Every strategy starts with the same capital, so the cash it holds is part of its surplus.
SELECT
  strategy,
  COUNT(*)                                           AS scenarios,
  ROUND(AVG(surplus) / 1e6, 2)                       AS avg_surplus_m,
  ROUND(MIN(surplus) / 1e6, 2)                       AS worst_surplus_m,
  ROUND(AVG(CASE WHEN surplus < 0 THEN 1.0 ELSE 0.0 END), 3) AS prob_negative
FROM scenario_result
GROUP BY strategy
ORDER BY worst_surplus_m DESC;
