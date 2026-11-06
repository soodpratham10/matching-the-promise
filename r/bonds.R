# The bond shelf and the yield curve
#
# Everything on the shelf is a default-free government bond with annual cash flows:
# zero-coupon strips (one payment at maturity) and annual-coupon bonds.

# Strip maturities on the game shelf (used for full immunization and the game)
STRIP_SHELF <- c(1, 2, 3, 5, 7, 10, 15, 20, 25, 30, 40, 50)

# Strip maturities the player can buy in the game
GAME_BUCKETS <- c(2, 5, 10, 20, 30, 50)

# Key rate points for key rate durations
KEY_RATES <- c(1, 2, 5, 10, 20, 30, 50)

# Cash flows of a bond on the yearly grid 1..horizon
# coupon_rate = 0 gives a zero-coupon strip
bond_cashflows <- function(face, coupon_rate, maturity, horizon = maturity) {
  if (maturity > horizon) stop("maturity is beyond the horizon")
  cf <- numeric(horizon)
  cf[seq_len(maturity)] <- face * coupon_rate
  cf[maturity] <- cf[maturity] + face
  cf
}

# Price of a bond at a flat yield i
bond_price <- function(face, coupon_rate, maturity, i) {
  pv_flat(bond_cashflows(face, coupon_rate, maturity), seq_len(maturity), i)
}

# Spot curve: a base rate plus a level shift and a slope (twist) pivoting at 10 years.
# s(m) = base + level + slope * (m - 10) / 10, floored at 0.25%
spot_curve <- function(m, level = 0, slope = 0, base = 0.05, floor = 0.0025) {
  pmax(base + level + slope * (m - 10) / 10, floor)
}

# Present value using the spot curve (each cash flow discounted at its own spot rate)
pv_curve <- function(cf, t, level = 0, slope = 0, base = 0.05) {
  sum(cf * (1 + spot_curve(t, level, slope, base))^(-t))
}

# The coupon-bond shelf as a table: one 4% annual-coupon bond for each maturity 1..30
coupon_shelf <- function(coupon_rate = 0.04, max_maturity = 30, i = 0.05) {
  m <- seq_len(max_maturity)
  data.frame(bond_id = sprintf("C%02d", m),
             type = "coupon",
             coupon_rate = coupon_rate,
             maturity = m,
             price_per_100 = sapply(m, function(k) bond_price(100, coupon_rate, k, i)))
}

# The strip shelf as a table
strip_shelf <- function(maturities = STRIP_SHELF, i = 0.05) {
  data.frame(bond_id = sprintf("S%02d", maturities),
             type = "strip",
             coupon_rate = 0,
             maturity = maturities,
             price_per_100 = 100 * (1 + i)^(-maturities))
}
