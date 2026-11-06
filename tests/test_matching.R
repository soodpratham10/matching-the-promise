library(testthat)
source("../r/promise.R")
source("../r/bonds.R")
source("../r/matching.R")

test_that("a two-year dedication matches the hand calculation", {
  # Pay 100 at t = 1 and t = 2 with 10% coupon bonds.
  # F2 = 100 / 1.1 = 90.9091; F1 = (100 - 0.1 * 90.9091) / 1.1 = 82.6446
  d <- dedicate_portfolio(c(100, 100), coupon_rate = 0.10, max_coupon_maturity = 2)
  expect_equal(d$coupon_face, c(82.64462809917354, 90.9090909090909), tolerance = 1e-12)
  expect_equal(d$gap, c(0, 0), tolerance = 1e-9)
  expect_equal(length(d$strip_face), 0)
})

test_that("strips cover the years beyond the last coupon bond", {
  d <- dedicate_portfolio(c(100, 100, 50), coupon_rate = 0.10, max_coupon_maturity = 2)
  expect_equal(d$strip_face, 50)
  expect_equal(d$asset_cf, c(100, 100, 50), tolerance = 1e-12)
})

liab <- liability_cashflows()
ded <- dedicate_portfolio(liab$cashflow)

test_that("the block is matched exactly every year", {
  expect_equal(length(ded$coupon_face), 30)
  expect_equal(length(ded$strip_face), 15)
  expect_true(max(abs(ded$gap)) < 1e-4)
  expect_true(all(ded$coupon_face > 0))
})

test_that("the block's matched portfolio has the expected faces", {
  expect_equal(ded$coupon_face[1], 47929639.91508733, tolerance = 1e-10)
  expect_equal(ded$coupon_face[30], 17642424.711349357, tolerance = 1e-10)
  expect_equal(ded$strip_face[1], 15330938.564999364, tolerance = 1e-10)
  expect_equal(sum(ded$coupon_face), 1275918483.8936737, tolerance = 1e-10)
})

test_that("an exact match costs exactly the PV of the promise, at any rate", {
  for (r in c(0.02, 0.05, 0.09)) {
    expect_equal(dedication_cost(ded, r), pv_flat(liab$cashflow, liab$t, r), tolerance = 1e-10)
  }
})

test_that("the year-by-year table adds up", {
  tab <- dedication_table(ded, liab$cashflow)
  expect_equal(nrow(tab), 45)
  expect_true(max(abs(tab$gap)) < 1e-4)
  expect_equal(tab$coupons[1], 0.04 * sum(ded$coupon_face), tolerance = 1e-12)
})
