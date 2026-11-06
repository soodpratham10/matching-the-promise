# Chapter 1: The Promise
# The liability of a closed annuity block, and how sensitive it is to interest rates.
#
# Prairie Promise Annuities pays each surviving retiree a level amount at the end of
# every year. Survival follows a Gompertz-Makeham law with our own illustrative
# parameters: mu(x) = A + B * c^x.

# Default block assumptions (illustrative only, not calibrated to real data)
BLOCK <- list(
  n_lives  = 10000,   # retirees in the closed block
  payment  = 10000,   # annual payment per retiree, paid at the end of each year
  age      = 65,      # age of every retiree at the valuation date
  max_age  = 110,     # nobody is paid beyond this age
  A        = 0.0001,  # Makeham constant
  B        = 0.00002, # Gompertz level
  c        = 1.10,    # Gompertz growth
  i        = 0.05     # flat valuation rate
)

# t-year survival probability under Gompertz-Makeham:
# tpx = exp( -A t - B c^x (c^t - 1) / ln c )
makeham_tpx <- function(x, t, A = BLOCK$A, B = BLOCK$B, c = BLOCK$c) {
  exp(-A * t - B * c^x * (c^t - 1) / log(c))
}

# Expected cash flows of the block: n_lives * payment * tpx at t = 1, 2, ..., max_age - age
liability_cashflows <- function(n_lives = BLOCK$n_lives, payment = BLOCK$payment,
                                age = BLOCK$age, max_age = BLOCK$max_age,
                                A = BLOCK$A, B = BLOCK$B, c = BLOCK$c) {
  if (max_age <= age) stop("max_age must be above age")
  t <- seq_len(max_age - age)
  p <- makeham_tpx(age, t, A, B, c)
  data.frame(t = t, survival = p, cashflow = n_lives * payment * p)
}

# Present value of cash flows cf at times t, at a flat effective rate i
pv_flat <- function(cf, t, i) sum(cf * (1 + i)^(-t))

# Present-value weights of each cash flow
pv_weights <- function(cf, t, i) {
  w <- cf * (1 + i)^(-t)
  w / sum(w)
}

# Macaulay duration: PV-weighted average time
mac_duration <- function(cf, t, i) sum(t * pv_weights(cf, t, i))

# Modified duration: v * Macaulay duration
mod_duration <- function(cf, t, i) mac_duration(cf, t, i) / (1 + i)

# Macaulay convexity: PV-weighted average of t^2
mac_convexity <- function(cf, t, i) sum(t^2 * pv_weights(cf, t, i))

# Modified convexity: v^2 * PV-weighted average of t(t + 1)
mod_convexity <- function(cf, t, i) sum(t * (t + 1) * pv_weights(cf, t, i)) / (1 + i)^2

# All the rate-sensitivity measures in one row
rate_profile <- function(cf, t, i) {
  data.frame(pv = pv_flat(cf, t, i),
             mac_duration = mac_duration(cf, t, i),
             mod_duration = mod_duration(cf, t, i),
             mac_convexity = mac_convexity(cf, t, i),
             mod_convexity = mod_convexity(cf, t, i))
}

# Approximate the PV at a new rate i1, starting from rate i0.
# "macaulay": P(i0) * ((1 + i0) / (1 + i1))^Dmac
# "modified": first-order Taylor, P(i0) * (1 - (i1 - i0) Dmod)
# "convexity": second-order Taylor, adds 0.5 (i1 - i0)^2 Cmod
approx_pv <- function(cf, t, i0, i1, method = c("macaulay", "modified", "convexity")) {
  method <- match.arg(method)
  p0 <- pv_flat(cf, t, i0)
  d  <- i1 - i0
  switch(method,
         macaulay  = p0 * ((1 + i0) / (1 + i1))^mac_duration(cf, t, i0),
         modified  = p0 * (1 - d * mod_duration(cf, t, i0)),
         convexity = p0 * (1 - d * mod_duration(cf, t, i0) + 0.5 * d^2 * mod_convexity(cf, t, i0)))
}

# Surplus of assets over liabilities at a flat rate i
surplus_flat <- function(asset_cf, asset_t, liab_cf, liab_t, i) {
  pv_flat(asset_cf, asset_t, i) - pv_flat(liab_cf, liab_t, i)
}
