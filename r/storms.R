# Chapter 4: Rate Storms
#
# Real yield curves do not move in parallel. This chapter measures exposure to each part
# of the curve (key rate durations), applies twists and random level-and-slope shocks,
# and runs 20-year storms through each strategy: the engine behind the game.

# ---------- Key rate durations ----------

# Triangular bump for key point number k: 1 at the key, falling linearly to 0 at the
# neighbouring keys, flat beyond the first and last keys. The bumps add up to 1 everywhere.
key_bump <- function(m, k, keys = KEY_RATES) {
  key <- keys[k]
  lo <- if (k > 1) keys[k - 1] else NA
  hi <- if (k < length(keys)) keys[k + 1] else NA
  sapply(m, function(x) {
    if (x == key) return(1)
    if (x < key) return(if (is.na(lo)) 1 else max(0, (x - lo) / (key - lo)))
    if (is.na(hi)) 1 else max(0, (hi - x) / (hi - key))
  })
}

# Key rate durations at a flat base rate, by central difference with bump size h
key_rate_durations <- function(cf, t, base = 0.05, keys = KEY_RATES, h = 1e-4) {
  P <- sum(cf * (1 + base)^(-t))
  krd <- sapply(seq_along(keys), function(k) {
    b <- key_bump(t, k, keys)
    up <- sum(cf * (1 + base + h * b)^(-t))
    dn <- sum(cf * (1 + base - h * b)^(-t))
    -(up - dn) / (2 * h * P)
  })
  setNames(krd, paste0(keys, "y"))
}

# ---------- Instant shocks ----------

# Surplus after an instant level-and-slope shock to the spot curve
shock_surplus <- function(asset_cf, asset_t, liab_cf, liab_t, level = 0, slope = 0, base = 0.05) {
  pv_curve(asset_cf, asset_t, level, slope, base) - pv_curve(liab_cf, liab_t, level, slope, base)
}

# Random level and slope shocks (normal), reproducible from a seed
random_shocks <- function(n = 1000, sd_level = 0.01, sd_slope = 0.005, seed = 2026) {
  set.seed(seed)
  data.frame(scenario = seq_len(n),
             level = rnorm(n, 0, sd_level),
             slope = rnorm(n, 0, sd_slope))
}

# ---------- 20-year storms ----------

STORMS <- c("Calm seas" = "calm", "Rate crash" = "crash", "Rate spike" = "spike",
            "Steepener" = "steepener", "Inversion" = "inversion", "Random storm" = "random")

# Level and slope of the curve at the start of years 0..years
storm_path <- function(kind = "calm", years = 20, seed = 1) {
  y <- 0:years
  level <- numeric(years + 1)
  slope <- numeric(years + 1)
  ramp <- function(n) c(0, pmin(seq_len(years), n))   # 0, 1, 2, ..., n, n, n
  if (kind == "crash") level <- -0.005 * ramp(5)
  else if (kind == "spike") level <- 0.005 * ramp(6)
  else if (kind == "steepener") slope <- 0.004 * ramp(5)
  else if (kind == "inversion") { slope <- -0.004 * ramp(5); level <- 0.005 * ramp(2) }
  else if (kind == "random") {
    set.seed(seed)
    e_level <- rnorm(years, 0, 0.0075)
    e_slope <- rnorm(years, 0, 0.004)
    for (k in 2:(years + 1)) {
      level[k] <- 0.9 * level[k - 1] + e_level[k - 1]
      slope[k] <- 0.8 * slope[k - 1] + e_slope[k - 1]
    }
  } else if (kind != "calm") stop("unknown storm: ", kind)
  data.frame(year = y, level = level, slope = slope)
}

# ---------- Strategies ----------

# Each strategy is a set of strips (face, maturity) plus cash, bought with the same budget:
# the PV of the liabilities plus starting capital.
strategy_budget <- function(liab_cf, liab_t, i = 0.05, capital_ratio = 0.05) {
  (1 + capital_ratio) * pv_flat(liab_cf, liab_t, i)
}

make_strategy <- function(name, liab_cf, liab_t, i = 0.05, capital_ratio = 0.05) {
  budget <- strategy_budget(liab_cf, liab_t, i, capital_ratio)
  P <- pv_flat(liab_cf, liab_t, i)
  s <- switch(name,
    matched = list(face = liab_cf, maturity = liab_t),
    redington = { r <- redington_pair(liab_cf, liab_t, i, 2, 30); list(face = r$face, maturity = r$maturity) },
    full = { f <- full_immunization(liab_cf, liab_t, i); list(face = f$face, maturity = f$maturity) },
    all_cash = list(face = 0, maturity = 1),
    all_long = list(face = P * (1 + i)^30, maturity = 30),
    stop("unknown strategy: ", name))
  s$cash <- budget - sum(s$face * (1 + i)^(-s$maturity))
  s$name <- name
  s
}

STRATEGY_LABELS <- c(matched = "Cash-flow matched", redington = "Redington barbell (2 and 30 years)",
                     full = "Full immunization", all_cash = "All cash", all_long = "All in 30-year strips")

# The player's portfolio: fractions of the budget in each game bucket, the rest in cash
player_strategy <- function(alloc, liab_cf, liab_t, i = 0.05, capital_ratio = 0.05,
                            buckets = GAME_BUCKETS) {
  if (length(alloc) != length(buckets)) stop("one allocation per bucket")
  if (any(alloc < 0) || sum(alloc) > 1 + 1e-9) stop("allocations must be between 0 and 100% in total")
  budget <- strategy_budget(liab_cf, liab_t, i, capital_ratio)
  list(face = alloc * budget * (1 + i)^buckets, maturity = buckets,
       cash = budget * (1 - sum(alloc)), name = "player")
}

# ---------- The simulation ----------

# Run a strategy through a storm path. Each year:
#   cash grows at last year's one-year rate, maturing strips are added, the year's
#   liability payment is made; then everything left is valued on the new curve.
simulate_storm <- function(strategy, liab_cf, liab_t, path) {
  face <- strategy$face; mat <- strategy$maturity
  cash <- strategy$cash
  years <- max(path$year)
  out <- data.frame(year = path$year, one_year_rate = NA, ten_year_rate = NA, cash = NA,
                    pv_assets = NA, pv_liabilities = NA, surplus = NA)
  for (k in seq_len(years + 1)) {
    y <- path$year[k]
    if (y > 0) {
      r1 <- spot_curve(1, path$level[k - 1], path$slope[k - 1])
      cash <- cash * (1 + r1) + sum(face[mat == y]) - sum(liab_cf[liab_t == y])
    }
    ra <- mat > y; rl <- liab_t > y
    pa <- sum(face[ra] * (1 + spot_curve(mat[ra] - y, path$level[k], path$slope[k]))^(-(mat[ra] - y)))
    pl <- sum(liab_cf[rl] * (1 + spot_curve(liab_t[rl] - y, path$level[k], path$slope[k]))^(-(liab_t[rl] - y)))
    out$one_year_rate[k] <- spot_curve(1, path$level[k], path$slope[k])
    out$ten_year_rate[k] <- spot_curve(10, path$level[k], path$slope[k])
    out$cash[k] <- cash
    out$pv_assets[k] <- pa
    out$pv_liabilities[k] <- pl
    out$surplus[k] <- cash + pa - pl
  }
  out
}

# ---------- Scoring ----------

# Score: worst surplus over the storm as a share of the starting capital (surplus at year 0)
storm_score <- function(sim) min(sim$surplus) / sim$surplus[1]

storm_grade <- function(score) {
  if (score >= 0.9) "A" else if (score >= 0.6) "B" else if (score >= 0.25) "C" else if (score >= 0) "D" else "F"
}

STORM_TITLES <- c(A = "Grandmaster of Matching", B = "Steady Hand", C = "Lucky Survivor",
                  D = "Running on Fumes", F = "Sunk by the Storm")

# Status each year, against the starting capital
storm_status <- function(sim) {
  cap <- sim$surplus[1]
  ifelse(sim$surplus >= 0.6 * cap, "Safe", ifelse(sim$surplus >= 0, "Drifting", "Underwater"))
}

# Newspaper headlines for notable years
storm_headlines <- function(sim) {
  st <- storm_status(sim)
  out <- character(0)
  for (k in 2:nrow(sim)) {
    d10 <- 10000 * (sim$ten_year_rate[k] - sim$ten_year_rate[k - 1])
    news <- NULL
    if (st[k] == "Underwater" && st[k - 1] != "Underwater") {
      news <- "MARKET WATCH: the promise now costs more than everything the fund owns"
    } else if (st[k] != "Underwater" && st[k - 1] == "Underwater") {
      news <- "Back above water: assets cover the promise again"
    } else if (d10 <= -25) {
      news <- sprintf("Rates tumble %.0f basis points: every future cheque just got more expensive", -d10)
    } else if (d10 >= 25) {
      news <- sprintf("Rates jump %.0f basis points: long bonds take a beating", d10)
    } else if (st[k] == "Drifting" && st[k - 1] == "Safe") {
      news <- "Analysts warn the fund is drifting off its match"
    }
    if (!is.null(news)) out <- c(out, sprintf("Year %d: %s", sim$year[k], news))
  }
  out
}

# Compare every textbook strategy (and optionally the player's) under one storm
compare_strategies <- function(liab_cf, liab_t, path, player = NULL) {
  names_ <- names(STRATEGY_LABELS)
  strats <- lapply(names_, make_strategy, liab_cf = liab_cf, liab_t = liab_t)
  labels <- unname(STRATEGY_LABELS)
  if (!is.null(player)) { strats <- c(list(player), strats); labels <- c("Your portfolio", labels) }
  rows <- lapply(strats, function(s) {
    sim <- simulate_storm(s, liab_cf, liab_t, path)
    sc <- storm_score(sim)
    data.frame(worst_surplus = min(sim$surplus), final_surplus = sim$surplus[nrow(sim)],
               score = sc, grade = storm_grade(sc))
  })
  cbind(strategy = labels, do.call(rbind, rows))
}
