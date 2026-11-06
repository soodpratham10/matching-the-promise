library(testthat)
source("../r/promise.R")

# A small case worked by hand: 100 at t = 1 and 200 at t = 2, at i = 10%
cf <- c(100, 200); tt <- c(1, 2)
# PV = 100/1.1 + 200/1.21 = 90.9091 + 165.2893 = 256.1983
# D  = (1 * 90.9091 + 2 * 165.2893) / 256.1983 = 1.645161
# C  = (1 * 90.9091 + 4 * 165.2893) / 256.1983 = 2.935484

test_that("present value of two payments matches the hand calculation", {
  expect_equal(pv_flat(cf, tt, 0.10), 256.198347107438, tolerance = 1e-10)
})

test_that("duration and convexity of two payments match the hand calculation", {
  expect_equal(mac_duration(cf, tt, 0.10), 1.6451612903225805, tolerance = 1e-10)
  expect_equal(mod_duration(cf, tt, 0.10), 1.6451612903225805 / 1.1, tolerance = 1e-10)
  expect_equal(mac_convexity(cf, tt, 0.10), 2.935483870967742, tolerance = 1e-10)
  # Cmod = v^2 * (2 * 90.9091 + 6 * 165.2893) / 256.1983 = 3.785657
  expect_equal(mod_convexity(cf, tt, 0.10), 3.7856571580911753, tolerance = 1e-10)
})

test_that("a single payment has duration equal to its time and convexity t^2", {
  expect_equal(mac_duration(500, 7, 0.05), 7)
  expect_equal(mac_convexity(500, 7, 0.05), 49)
  expect_equal(mod_convexity(500, 7, 0.05), 7 * 8 / 1.05^2)
})

test_that("Gompertz-Makeham survival behaves", {
  expect_equal(makeham_tpx(65, 0), 1)
  # with B = 0 survival is exp(-A t)
  expect_equal(makeham_tpx(65, 10, A = 0.01, B = 0), exp(-0.1))
  expect_equal(makeham_tpx(65, 1), 0.9896637927083427, tolerance = 1e-10)
  expect_equal(makeham_tpx(65, 10), 0.8478970540820318, tolerance = 1e-10)
  expect_true(all(diff(makeham_tpx(65, 1:45)) < 0))   # survival keeps falling
})

liab <- liability_cashflows()

test_that("the Prairie Promise block has the expected cash flows", {
  expect_equal(nrow(liab), 45)
  expect_equal(liab$cashflow[1], 98966379.27083427, tolerance = 1e-10)
  expect_equal(liab$cashflow[45], 61001.408466658766, tolerance = 1e-8)
  expect_equal(sum(liab$cashflow), 2037275726.3623705, tolerance = 1e-10)
})

test_that("the block's rate profile at 5% matches the independent calculation", {
  rp <- rate_profile(liab$cashflow, liab$t, 0.05)
  expect_equal(rp$pv, 1174851028.8876452, tolerance = 1e-10)
  expect_equal(rp$mac_duration, 9.810073918136291, tolerance = 1e-10)
  expect_equal(rp$mod_duration, 9.342927541082181, tolerance = 1e-10)
  expect_equal(rp$mac_convexity, 150.2832464630423, tolerance = 1e-10)
  expect_equal(rp$mod_convexity, 145.20936088995794, tolerance = 1e-10)
})

test_that("PV approximations at 6% are ordered as expected", {
  exact <- pv_flat(liab$cashflow, liab$t, 0.06)
  expect_equal(exact, 1073075449.66894, tolerance = 1e-10)
  expect_equal(approx_pv(liab$cashflow, liab$t, 0.05, 0.06, "macaulay"), 1070530346.6860018, tolerance = 1e-10)
  expect_equal(approx_pv(liab$cashflow, liab$t, 0.05, 0.06, "modified"), 1065085548.543014, tolerance = 1e-10)
  expect_equal(approx_pv(liab$cashflow, liab$t, 0.05, 0.06, "convexity"), 1073615516.8952982, tolerance = 1e-10)
  # adding convexity gets much closer than duration alone
  err_mod  <- abs(approx_pv(liab$cashflow, liab$t, 0.05, 0.06, "modified") - exact)
  err_conv <- abs(approx_pv(liab$cashflow, liab$t, 0.05, 0.06, "convexity") - exact)
  expect_true(err_conv < err_mod / 10)
})

test_that("surplus is zero when assets copy the liabilities", {
  expect_equal(surplus_flat(liab$cashflow, liab$t, liab$cashflow, liab$t, 0.07), 0)
})

test_that("bad ages are rejected", {
  expect_error(liability_cashflows(age = 110, max_age = 110))
})
