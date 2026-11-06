library(testthat)
source("../r/promise.R")
source("../r/bonds.R")
source("../r/immunize.R")
source("../r/storms.R")

liab <- liability_cashflows()
L <- liab$cashflow; t <- liab$t

test_that("key rate bumps are triangles that add up to one", {
  expect_equal(key_bump(c(5, 7.5, 10, 12), 4), c(0, 0.5, 1, 0.8))   # key 10 between 5 and 20
  expect_equal(key_bump(c(0.5, 1, 1.5), 1), c(1, 1, 0.5))           # flat before the first key
  total <- Reduce(`+`, lapply(seq_along(KEY_RATES), function(k) key_bump(1:50, k)))
  expect_equal(total, rep(1, 50))
})

test_that("key rate durations add up to the modified duration", {
  krd <- key_rate_durations(L, t)
  expect_equal(length(krd), 7)
  expect_equal(sum(krd), mod_duration(L, t, 0.05), tolerance = 1e-6)
  expect_equal(unname(krd), c(0.0764057927, 0.3639456078, 1.2602557648, 3.0965491055,
                              3.2563916968, 1.2270524481, 0.0623296487), tolerance = 1e-8)
  # a 10-year strip only has exposure to the 10-year key rate
  k10 <- key_rate_durations(100, 10)
  expect_equal(unname(k10), c(0, 0, 0, 10 / 1.05, 0, 0, 0), tolerance = 1e-6)
})

test_that("twists hurt the barbell far more than full immunization", {
  bar <- redington_pair(L, t, 0.05, 2, 30)
  full <- full_immunization(L, t, 0.05)
  s_bar  <- shock_surplus(bar$face, bar$maturity, L, t, slope = 0.01)
  s_full <- shock_surplus(full$face, full$maturity, L, t, slope = 0.01)
  expect_true(s_bar < -50e6)
  expect_true(abs(s_full) < 5e6)
})

test_that("random shocks are reproducible", {
  a <- random_shocks(200, seed = 11); b <- random_shocks(200, seed = 11)
  expect_identical(a, b)
  expect_equal(nrow(a), 200)
})

test_that("storm paths have the stated shape", {
  expect_equal(storm_path("calm")$level, rep(0, 21))
  expect_equal(storm_path("crash")$level[1:7], c(0, -0.005, -0.01, -0.015, -0.02, -0.025, -0.025))
  inv <- storm_path("inversion")
  expect_equal(inv$level[1:4], c(0, 0.005, 0.01, 0.01))
  expect_equal(inv$slope[7], -0.02)
  expect_identical(storm_path("random", seed = 5), storm_path("random", seed = 5))
  expect_error(storm_path("hurricane"))
})

test_that("every strategy starts with the same capital", {
  cap <- 0.05 * pv_flat(L, t, 0.05)
  for (s in names(STRATEGY_LABELS)) {
    sim <- simulate_storm(make_strategy(s, L, t), L, t, storm_path("calm"))
    expect_equal(sim$surplus[1], cap, tolerance = 1e-9)
  }
})

test_that("with calm seas the matched block just grows its capital at 5%", {
  sim <- simulate_storm(make_strategy("matched", L, t), L, t, storm_path("calm"))
  cap <- 0.05 * pv_flat(L, t, 0.05)
  expect_equal(sim$cash[2], cap * 1.05, tolerance = 1e-9)
  expect_equal(sim$surplus[21], cap * 1.05^20, tolerance = 1e-9)
  expect_equal(sim$surplus[21], 155861476.94170803, tolerance = 1e-9)
})

test_that("deterministic storms give the independent results", {
  run <- function(s, kind) simulate_storm(make_strategy(s, L, t), L, t, storm_path(kind))
  expect_equal(storm_score(run("all_cash", "crash")), -5.465966122410611, tolerance = 1e-8)
  expect_equal(storm_score(run("all_long", "spike")), -26.818253479588794, tolerance = 1e-8)
  red <- run("redington", "steepener")
  expect_equal(storm_score(red), -2.3941698726791083, tolerance = 1e-8)
  expect_equal(red$surplus[21], 43077434.79747629, tolerance = 1e-8)
  full <- run("full", "steepener")
  expect_equal(storm_score(full), 1)
  expect_equal(full$surplus[21], 114158905.77207953, tolerance = 1e-8)
})

test_that("the player's portfolio is built from the budget", {
  p <- player_strategy(c(0, 0, 1, 0, 0, 0), L, t)
  expect_equal(p$face[3], 2009393954.6299868, tolerance = 1e-10)
  expect_equal(p$cash, 0)
  sim <- simulate_storm(p, L, t, storm_path("inversion"))
  expect_equal(storm_score(sim), -1.324105895369997, tolerance = 1e-8)
  expect_error(player_strategy(c(0.5, 0.6, 0, 0, 0, 0), L, t))
})

test_that("grades, statuses and headlines follow the rules", {
  expect_equal(sapply(c(1, 0.7, 0.3, 0.1, -0.2), storm_grade), c("A", "B", "C", "D", "F"))
  sim <- data.frame(year = 0:3, ten_year_rate = c(0.05, 0.05, 0.045, 0.045),
                    surplus = c(100, 70, 30, -10))
  expect_equal(storm_status(sim), c("Safe", "Safe", "Drifting", "Underwater"))
  h <- storm_headlines(sim)
  expect_equal(length(h), 2)
  expect_match(h[1], "Year 2: Rates tumble 50 basis points")
  calm <- simulate_storm(make_strategy("full", L, t), L, t, storm_path("calm"))
  expect_equal(length(storm_headlines(calm)), 0)
})

test_that("the comparison table covers every strategy", {
  tab <- compare_strategies(L, t, storm_path("crash"))
  expect_equal(nrow(tab), 5)
  expect_equal(tab$grade[tab$strategy == "All cash"], "F")
})
