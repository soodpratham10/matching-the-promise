[← Overview](../README.md)

# Getting started

Everything you need to run Matching the Promise on your own computer. If you just want to play, the **[live game](https://soodpratham10.shinyapps.io/matching-the-promise/)** needs no installation.

## 1. Install the packages

```r
install.packages(c("testthat", "DBI", "RSQLite", "shiny"))
```

## 2. Run the tests

From the project root in R:

```r
setwd("tests")
testthat::test_file("test_promise.R")    # Chapter 1               29 tests
testthat::test_file("test_bonds.R")      # bonds and the curve     15 tests
testthat::test_file("test_matching.R")   # Chapter 2               19 tests
testthat::test_file("test_immunize.R")   # Chapter 3               25 tests
testthat::test_file("test_storms.R")     # Chapter 4 and the game  42 tests
setwd("..")
```

Every file should report `FAIL 0`: 130 tests in all.

## 3. Build the scenario database

The database file isn't stored in the repository. This rebuilds it and prints every query:

```r
source("r/database.R")
con <- build_alm_database()     # writes sql/alm.sqlite
run_all_queries(con)
DBI::dbDisconnect(con)
```

You can also open `sql/alm.sqlite` in DB Browser for SQLite and run the `.sql` files there.

## 4. Open the game

```r
shiny::runApp("app")
```

## 5. The Excel cross-check

Open `excel/promise_crosscheck.xlsx`. The blue cells on `Inputs` are the assumptions. The `Check` sheet compares 22 results with the R engine and should say **ALL PASS**.

## How the pieces map to code

| Chapter | Engine | SQL | Excel sheet |
|---|---|---|---|
| [1. The Promise](chapters/01-the-promise.md) | `r/promise.R` | `liability_profile.sql` | `Promise` |
| [2. Exact Matching](chapters/02-exact-matching.md) | `r/matching.R`, `r/bonds.R` | `portfolio_summary.sql` | `Matching` |
| [3. Immunization](chapters/03-immunization.md) | `r/immunize.R` | `portfolio_summary.sql` | `Immunization` |
| [4. Rate Storms](chapters/04-rate-storms.md) | `r/storms.R`, `r/database.R` | `scenario_summary.sql`, `tail_loss.sql`, `worst_scenarios.sql` | |
| [The game](the-game.md) | `r/storms.R` | | |

## Repository layout

```
r/          the engine: one file per chapter, plus bonds and the database builder
sql/        the schema and the scenario-study queries
excel/      the independent cross-check workbook
tests/      automated tests with hand-checked expected values
app/        the Shiny game, The Rate Storm
docs/       chapter pages, the game rules and this guide
deploy.R    publishes the game to shinyapps.io
```
