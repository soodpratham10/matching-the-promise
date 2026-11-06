-- Matching the Promise: database schema
-- Rebuilt from scratch by build_alm_database() in r/database.R

DROP TABLE IF EXISTS liability;
DROP TABLE IF EXISTS bond_shelf;
DROP TABLE IF EXISTS holding;
DROP TABLE IF EXISTS scenario;
DROP TABLE IF EXISTS scenario_result;
DROP TABLE IF EXISTS key_rate;

-- The promise: expected payment to the block in each future year
CREATE TABLE liability (
  t               INTEGER PRIMARY KEY,  -- years from the valuation date
  survival        REAL NOT NULL,        -- probability a 65-year-old is alive at t
  cashflow        REAL NOT NULL,        -- expected payment at t
  discount_factor REAL NOT NULL         -- (1.05)^(-t)
);

-- Every bond on the shelf, priced at the 5% flat curve
CREATE TABLE bond_shelf (
  bond_id       TEXT PRIMARY KEY,
  type          TEXT NOT NULL CHECK (type IN ('strip', 'coupon')),
  coupon_rate   REAL NOT NULL,
  maturity      INTEGER NOT NULL,
  price_per_100 REAL NOT NULL
);

-- The strips each strategy holds
CREATE TABLE holding (
  strategy TEXT NOT NULL,
  maturity INTEGER NOT NULL,
  face     REAL NOT NULL,
  cost     REAL NOT NULL,                 -- face discounted at 5%
  PRIMARY KEY (strategy, maturity)
);

-- Random instant shocks to the level and slope of the curve
CREATE TABLE scenario (
  scenario INTEGER PRIMARY KEY,
  level    REAL NOT NULL,
  slope    REAL NOT NULL
);

-- Surplus of each strategy after each shock
CREATE TABLE scenario_result (
  strategy TEXT NOT NULL,
  scenario INTEGER NOT NULL REFERENCES scenario (scenario),
  surplus  REAL NOT NULL,
  PRIMARY KEY (strategy, scenario)
);

-- Key rate durations of the promise and of each strategy's bonds
CREATE TABLE key_rate (
  portfolio TEXT NOT NULL,
  key_year  INTEGER NOT NULL,
  krd       REAL NOT NULL,
  PRIMARY KEY (portfolio, key_year)
);
