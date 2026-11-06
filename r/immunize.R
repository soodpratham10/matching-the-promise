# Chapter 3: Immunization (Redington and full)
#
# Redington: match the PV and the duration of the liabilities, and have more convexity.
# Then small parallel shifts in a flat rate cannot create a loss.
# Full immunization: bracket every liability payment with an earlier and a later asset,
# so that no parallel shift of any size can create a loss.

# Two strips at maturities m1 < m2 matching PV and Macaulay duration of the liabilities.
# PV split: P2 = PV * (D - m1) / (m2 - m1), P1 = PV - P2, faces = P * (1 + i)^m
redington_pair <- function(liab_cf, liab_t, i, m1, m2) {
  if (m1 >= m2) stop("m1 must be shorter than m2")
  P <- pv_flat(liab_cf, liab_t, i)
  D <- mac_duration(liab_cf, liab_t, i)
  if (D <= m1 || D >= m2) stop("the liability duration must lie between m1 and m2")
  P2 <- P * (D - m1) / (m2 - m1)
  P1 <- P - P2
  data.frame(maturity = c(m1, m2), cost = c(P1, P2), face = c(P1, P2) * (1 + i)^c(m1, m2))
}

# The three Redington conditions
redington_check <- function(asset_cf, asset_t, liab_cf, liab_t, i, tol = 1e-6) {
  pa <- pv_flat(asset_cf, asset_t, i);       pl <- pv_flat(liab_cf, liab_t, i)
  da <- mac_duration(asset_cf, asset_t, i);  dl <- mac_duration(liab_cf, liab_t, i)
  ca <- mac_convexity(asset_cf, asset_t, i); cl <- mac_convexity(liab_cf, liab_t, i)
  list(pv_assets = pa, pv_liabilities = pl,
       duration_assets = da, duration_liabilities = dl,
       convexity_assets = ca, convexity_liabilities = cl,
       pv_match = abs(pa - pl) <= tol * pl,
       duration_match = abs(da - dl) <= tol * dl,
       convexity_ok = ca > cl,
       immunized = abs(pa - pl) <= tol * pl && abs(da - dl) <= tol * dl && ca > cl)
}

# Full immunization: for each liability payment L at time t, buy the strips just before (a)
# and just after (b) it on the shelf, with
#   face_before = b / (a + b) * L * v^a      (a years before t)
#   face_after  = a / (a + b) * L * (1 + i)^b (b years after t)
# A payment that falls on a shelf maturity is matched by that strip directly.
full_immunization <- function(liab_cf, liab_t, i, shelf = STRIP_SHELF) {
  shelf <- sort(shelf)
  if (min(liab_t) < min(shelf) || max(liab_t) > max(shelf)) stop("liabilities fall outside the shelf")
  face <- numeric(length(shelf))
  for (k in seq_along(liab_t)) {
    tk <- liab_t[k]; Lk <- liab_cf[k]
    j <- which(shelf == tk)
    if (length(j) == 1) {
      face[j] <- face[j] + Lk
    } else {
      lo <- max(which(shelf < tk)); hi <- min(which(shelf > tk))
      a <- tk - shelf[lo]; b <- shelf[hi] - tk
      face[lo] <- face[lo] + b / (a + b) * Lk * (1 + i)^(-a)
      face[hi] <- face[hi] + a / (a + b) * Lk * (1 + i)^b
    }
  }
  data.frame(maturity = shelf, face = face, cost = face * (1 + i)^(-shelf))
}

# Surplus across a range of flat rates (for the surplus curve plot)
surplus_curve <- function(asset_cf, asset_t, liab_cf, liab_t, rates = seq(0.01, 0.10, by = 0.001)) {
  data.frame(rate = rates,
             surplus = sapply(rates, function(r) surplus_flat(asset_cf, asset_t, liab_cf, liab_t, r)))
}
