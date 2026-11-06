-- The promise measured in SQL: an independent check of the R engine.
-- PV, Macaulay duration and Macaulay convexity at 5%, plus the expected number of payments.
SELECT
  SUM(cashflow * discount_factor)                                          AS pv,
  SUM(t * cashflow * discount_factor) / SUM(cashflow * discount_factor)    AS mac_duration,
  SUM(t * t * cashflow * discount_factor) / SUM(cashflow * discount_factor) AS mac_convexity,
  SUM(survival)                                                            AS expected_payments_per_person,
  SUM(cashflow)                                                            AS total_undiscounted
FROM liability;
