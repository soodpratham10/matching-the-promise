# Chapter 2: Exact Matching (cash-flow matching, also called dedication)
#
# Buy bonds so that every year the bond cash flows equal the liability cash flows.
# We use one annual-coupon bond for each maturity 1..max_coupon_maturity, and
# zero-coupon strips for the years beyond that.
#
# Work backwards from the last year. A coupon bond maturing in year k pays
# face * (1 + r) in year k, and every bond maturing after k pays a coupon r * face in year k:
#   F_k = ( L_k - r * sum_{j > k} F_j ) / (1 + r)

dedicate_portfolio <- function(liab_cf, coupon_rate = 0.04, max_coupon_maturity = 30) {
  H <- length(liab_cf)
  n_c <- min(max_coupon_maturity, H)
  coupon_face <- numeric(n_c)
  strip_face <- numeric(0)
  if (H > n_c) strip_face <- liab_cf[(n_c + 1):H]   # strips pay exactly L_k
  for (k in n_c:1) {
    later <- if (k < n_c) sum(coupon_face[(k + 1):n_c]) else 0
    coupon_face[k] <- (liab_cf[k] - coupon_rate * later) / (1 + coupon_rate)
  }
  if (any(coupon_face < 0)) warning("a coupon face is negative: coupons overshoot that year's payment")

  # Asset cash flows year by year
  asset_cf <- numeric(H)
  for (k in seq_len(n_c)) {
    asset_cf <- asset_cf + c(bond_cashflows(coupon_face[k], coupon_rate, k, H))
  }
  if (H > n_c) asset_cf[(n_c + 1):H] <- asset_cf[(n_c + 1):H] + strip_face

  list(coupon_face = coupon_face,
       strip_face = strip_face,
       coupon_rate = coupon_rate,
       asset_cf = asset_cf,
       gap = asset_cf - liab_cf)
}

# Total cost of the matched portfolio at a flat rate i
dedication_cost <- function(ded, i) {
  pv_flat(ded$asset_cf, seq_along(ded$asset_cf), i)
}

# Year-by-year table: liability, coupons received, bonds maturing, strips maturing, gap
dedication_table <- function(ded, liab_cf) {
  H <- length(liab_cf)
  n_c <- length(ded$coupon_face)
  coupons <- sapply(seq_len(H), function(k) {
    if (k > n_c) 0 else ded$coupon_rate * sum(ded$coupon_face[k:n_c])
  })
  redemptions <- c(ded$coupon_face, rep(0, H - n_c))
  strips <- c(rep(0, n_c), ded$strip_face)
  data.frame(year = seq_len(H), liability = liab_cf, coupons = coupons,
             redemptions = redemptions, strips = strips,
             gap = coupons + redemptions + strips - liab_cf)
}
