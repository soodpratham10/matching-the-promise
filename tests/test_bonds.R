library(testthat)
source("../r/promise.R")
source("../r/bonds.R")

test_that("bond cash flows are laid out year by year", {
  expect_equal(bond_cashflows(1000, 0.04, 3), c(40, 40, 1040))
  expect_equal(bond_cashflows(1000, 0, 3, horizon = 5), c(0, 0, 1000, 0, 0))
  expect_error(bond_cashflows(1000, 0.04, 6, horizon = 5))
})

test_that("bond prices match the hand calculation", {
  # 40/1.05 + 40/1.05^2 + 1040/1.05^3 = 972.7675
  expect_equal(bond_price(1000, 0.04, 3, 0.05), 972.7675197062952, tolerance = 1e-10)
  expect_equal(bond_price(1000, 0.04, 3, 0.04), 1000)    # coupon = yield gives par
  expect_equal(bond_price(1000, 0, 10, 0.05), 1000 / 1.05^10)
})

test_that("the spot curve pivots at 10 years and is floored", {
  expect_equal(spot_curve(10, slope = 0.01), 0.05)
  expect_equal(spot_curve(20, slope = 0.01), 0.06)
  expect_equal(spot_curve(c(1, 30), level = -0.01), c(0.04, 0.04))
  expect_equal(spot_curve(1, level = -0.10), 0.0025)
})

test_that("PV on a flat curve equals the flat-rate PV", {
  expect_equal(pv_curve(c(40, 40, 1040), 1:3), bond_price(1000, 0.04, 3, 0.05))
})

test_that("the shelves have the right bonds", {
  cs <- coupon_shelf()
  expect_equal(nrow(cs), 30)
  expect_equal(cs$price_per_100[3], 97.27675197062952, tolerance = 1e-10)
  ss <- strip_shelf()
  expect_equal(ss$maturity, STRIP_SHELF)
  expect_equal(ss$price_per_100[ss$maturity == 10], 100 / 1.05^10)
})
