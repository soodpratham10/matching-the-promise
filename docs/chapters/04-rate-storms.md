[← Previous: Immunization](03-immunization.md) · [Overview](../../README.md)

# Chapter 4: Rate Storms

*Curves don't move in parallel.*

**Code:** [`r/storms.R`](../../r/storms.R), [`r/database.R`](../../r/database.R) · **Tests:** [`tests/test_storms.R`](../../tests/test_storms.R) (42) · **SQL:** [`sql/`](../../sql/)

## Beyond parallel shifts

Redington and full immunization both assume that the whole yield curve moves by the same amount. Real curves twist: short rates and long rates move by different amounts. Here the spot curve has a level and a slope that pivot at 10 years:

$$s(m) = 5\% + \text{level} + \text{slope} \times \frac{m - 10}{10}$$

floored at 0.25%. A slope of +1% leaves the 10-year rate alone, lifts the 20-year rate by 1% and lowers the 1-year rate by 0.9%.

## Key rate durations

A key rate duration measures exposure to one point of the curve. Bump the rate at key year $k$ by a triangle that is 1 at $k$ and falls to 0 at the neighbouring keys (1, 2, 5, 10, 20, 30 and 50 years):

$$KRD_k = -\frac{P(+h) - P(-h)}{2 h P}$$

The triangles add up to 1 everywhere, so the key rate durations add up to the modified duration.

| Key rate | Promise | Barbell 2/30 | Full immunization |
|---|---|---|---|
| 1 | 0.076 | 0 | 0.076 |
| 2 | 0.364 | 1.373 | 0.343 |
| 5 | 1.260 | 0 | 1.233 |
| 10 | 3.097 | 0 | 3.031 |
| 20 | 3.256 | 0 | 3.334 |
| 30 | 1.227 | 7.969 | 1.255 |
| 50 | 0.062 | 0 | 0.071 |
| **Total** | **9.343** | **9.343** | **9.343** |

All three have the same total, so all three look "immunized". But the barbell piles its exposure onto 2 and 30 years. When the curve steepens by 1%, the barbell's surplus falls by **$80.6 million**, against **$1.4 million** for full immunization.

## 1,000 random shocks (the SQL study)

`build_alm_database()` draws 1,000 random level shocks (standard deviation 1%) and slope shocks (0.5%), stores every strategy's surplus after each shock in SQLite, and the queries in `sql/` summarise them:

| Query | What it answers |
|---|---|
| `liability_profile.sql` | The promise's PV, duration and convexity, recomputed in SQL |
| `portfolio_summary.sql` | Each strategy's cost, strips held and duration |
| `scenario_summary.sql` | Average and worst surplus, and the chance it goes negative |
| `tail_loss.sql` | The 5th-percentile surplus (a 95% value-at-risk view) |
| `worst_scenarios.sql` | The three worst shocks for each strategy, and what the curve did |

Every strategy starts with the same $58.7 million of capital. The results (seed 2026):

| Strategy | Average surplus | Worst surplus | 5th percentile | Chance negative |
|---|---|---|---|---|
| Cash-flow matched | $58.74M | $58.74M | $58.74M | 0% |
| Full immunization | $59.24M | $56.04M | $57.42M | 0% |
| Redington barbell | $75.96M | -$87.98M | -$14.83M | 9.9% |
| All cash | $48.40M | -$438.21M | -$177.82M | 30.1% |
| All in 30-year strips | $147.43M | -$538.26M | -$374.75M | 44.4% |

The barbell has the higher *average* surplus, because its extra convexity pays off on most shocks, but it carries a real left tail. Its three worst shocks are the same three as full immunization's: steep twists of about +1% to +1.2% in slope. Full immunization shrugs them off; the barbell loses up to $88 million. Exact matching doesn't move at all: its surplus is just the capital.

## Twenty-year storms

The game runs each strategy through 20 years of moving rates, without rebalancing. Each year cash earns last year's one-year rate, maturing strips are added, the year's payments go out, and everything left is valued on the new curve. The deterministic storms:

| Storm | What happens |
|---|---|
| Calm seas | Nothing: the curve stays flat at 5% |
| Rate crash | Rates fall 0.5% a year for five years, to 2.5% |
| Rate spike | Rates rise 0.5% a year for six years, to 8% |
| Steepener | The slope rises 0.4% a year for five years, to +2% |
| Inversion | Rates rise 1% while the slope falls to -2% |
| Random storm | Level and slope follow mean-reverting random walks (game number = seed) |

Score: the worst surplus over the 20 years, as a share of the starting capital.

| Storm | Cash-flow matched | Redington barbell | Full immunization | All cash | All 30-year |
|---|---|---|---|---|---|
| Calm seas | A | A | A | A | A |
| Rate crash | A | A | A | **F** (-547%) | A |
| Rate spike | A | A | A | A | **F** (-2,682%) |
| Steepener | A | **F** (-239%) | A | **F** (-313%) | **F** (-1,082%) |
| Inversion | A | A | A | A | **F** (-1,799%) |

In 300 random storms in the tuning run, the barbell fell underwater 43% of the time. Full immunization and exact matching never did.

## Key functions

| Function | What it does |
|---|---|
| `key_bump()`, `key_rate_durations()` | Key rate exposure |
| `shock_surplus()`, `random_shocks()` | Instant level-and-slope shocks |
| `storm_path()`, `simulate_storm()` | The 20-year storms |
| `make_strategy()`, `player_strategy()` | The textbook strategies and the player's portfolio |
| `storm_score()`, `storm_grade()`, `storm_status()`, `storm_headlines()` | Scoring, the meter and the newspaper |
| `compare_strategies()` | Every strategy under one storm |
| `build_alm_database()`, `run_all_queries()` | The SQL study |
