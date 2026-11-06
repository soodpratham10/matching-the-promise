library(testthat)
source("../r/promise.R")
source("../r/bonds.R")
source("../r/immunize.R")

test_that("a Redington pair for one payment matches the hand calculation", {
  # Liability 100 at t = 3, i = 0, strips at 1 and 5:
  # P2 = 100 * (3 - 1) / (5 - 1) = 50, P1 = 50, faces equal costs at i = 0
  r <- redington_pair(100, 3, 0, 1, 5)
  expect_equal(r$cost, c(50, 50))
  expect_equal(r$face, c(50, 50))
  # convexity of assets 0.5 * 1 + 0.5 * 25 = 13 > 9
  chk <- redington_check(r$face, r$maturity, 100, 3, 0)
  expect_equal(chk$convexity_assets, 13)
  expect_true(chk$immunized)
})

test_that("Redington pairs need the duration between the two maturities", {
  expect_error(redington_pair(100, 3, 0.05, 5, 10))
  expect_error(redington_pair(100, 3, 0.05, 5, 1))
})

liab <- liability_cashflows()
L <- liab$cashflow; t <- liab$t

test_that("the 2-and-30 barbell passes all three Redington conditions", {
  r <- redington_pair(L, t, 0.05, 2, 30)
  expect_equal(r$face, c(933981120.0736965, 1416311842.6677258), tolerance = 1e-10)
  chk <- redington_check(r$face, r$maturity, L, t, 0.05)
  expect_true(chk$pv_match)
  expect_true(chk$duration_match)
  expect_equal(chk$convexity_assets, 253.92236538036138, tolerance = 1e-10)
  expect_true(chk$immunized)
  expect_equal(surplus_flat(r$face, r$maturity, L, t, 0.06), 4758662.574321628, tolerance = 1e-8)
})

test_that("the 5-and-20 pair matches duration but fails on convexity", {
  r <- redington_pair(L, t, 0.05, 5, 20)
  chk <- redington_check(r$face, r$maturity, L, t, 0.05)
  expect_true(chk$duration_match)
  expect_equal(chk$convexity_assets, 145.2518479534073, tolerance = 1e-10)
  expect_false(chk$convexity_ok)
  # so it loses money when rates move either way
  expect_equal(surplus_flat(r$face, r$maturity, L, t, 0.06), -226633.89465594292, tolerance = 1e-8)
  expect_true(surplus_flat(r$face, r$maturity, L, t, 0.04) < 0)
})

test_that("full immunization for one payment matches the hand calculation", {
  # Liability 100 at t = 4, shelf strips at 2 and 5, i = 0: a = 2, b = 1
  # before: 1/3 * 100 = 33.33, after: 2/3 * 100 = 66.67
  f <- full_immunization(100, 4, 0, shelf = c(2, 5))
  expect_equal(f$face, c(100 / 3, 200 / 3))
  expect_error(full_immunization(100, 60, 0.05))   # beyond the shelf
})

test_that("full immunization of the block", {
  f <- full_immunization(L, t, 0.05)
  expect_equal(f$face[1], 98966379.27083427, tolerance = 1e-10)   # year 1 is on the shelf
  expect_equal(f$face[12], 416740.02651, tolerance = 1e-8)        # the 50-year strip
  chk <- redington_check(f$face, f$maturity, L, t, 0.05)
  expect_true(chk$immunized)
  expect_equal(surplus_flat(f$face, f$maturity, L, t, 0.06), 94318.15816557407, tolerance = 1e-6)
  expect_equal(surplus_flat(f$face, f$maturity, L, t, 0.04), 132575.27917599678, tolerance = 1e-6)
  # no parallel shift of any size creates a loss
  sc <- surplus_curve(f$face, f$maturity, L, t, rates = seq(0.001, 0.15, by = 0.001))
  expect_true(all(sc$surplus > -1e-3))
})
