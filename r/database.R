# The SQL layer: store the promise, the shelf, every strategy's holdings and
# 1,000 random shocks in SQLite, then summarise them with the queries in sql/.
#
# Run from the project root:
#   source("r/database.R"); con <- build_alm_database(); run_all_queries(con); DBI::dbDisconnect(con)
# Needs the packages DBI and RSQLite.

for (f in c("promise.R", "bonds.R", "immunize.R", "storms.R")) source(file.path("r", f))

# Split a .sql file into single statements (SQLite runs one at a time from R)
read_sql_statements <- function(file) {
  txt <- paste(readLines(file, warn = FALSE), collapse = "\n")
  parts <- trimws(strsplit(txt, ";", fixed = TRUE)[[1]])
  # drop pieces that are only comments or blank
  keep <- sapply(parts, function(p) {
    lines <- trimws(strsplit(p, "\n", fixed = TRUE)[[1]])
    any(nchar(lines) > 0 & !startsWith(lines, "--"))
  })
  parts[keep]
}

# Run a query file and return the result of its (last) SELECT
run_sql_file <- function(con, file) {
  st <- read_sql_statements(file)
  for (s in st[-length(st)]) DBI::dbExecute(con, s)
  DBI::dbGetQuery(con, st[length(st)])
}

build_alm_database <- function(path = "sql/alm.sqlite", n_scenarios = 1000, seed = 2026, i = 0.05) {
  if (file.exists(path)) file.remove(path)
  con <- DBI::dbConnect(RSQLite::SQLite(), path)
  for (s in read_sql_statements("sql/schema.sql")) DBI::dbExecute(con, s)

  liab <- liability_cashflows()
  L <- liab$cashflow; t <- liab$t
  DBI::dbAppendTable(con, "liability",
                     data.frame(t = t, survival = liab$survival, cashflow = L,
                                discount_factor = (1 + i)^(-t)))
  DBI::dbAppendTable(con, "bond_shelf", rbind(strip_shelf(i = i), coupon_shelf(i = i)))

  # Holdings of every textbook strategy
  strats <- lapply(names(STRATEGY_LABELS), make_strategy, liab_cf = L, liab_t = t, i = i)
  hold <- do.call(rbind, lapply(strats, function(s) {
    data.frame(strategy = s$name, maturity = s$maturity, face = s$face,
               cost = s$face * (1 + i)^(-s$maturity))
  }))
  DBI::dbAppendTable(con, "holding", hold)

  # Random instant shocks and each strategy's surplus after them
  sh <- random_shocks(n_scenarios, seed = seed)
  DBI::dbAppendTable(con, "scenario", sh)
  res <- do.call(rbind, lapply(strats, function(s) {
    data.frame(strategy = s$name, scenario = sh$scenario,
               surplus = s$cash + mapply(function(lv, sl) shock_surplus(s$face, s$maturity, L, t, lv, sl),
                                         sh$level, sh$slope))
  }))
  DBI::dbAppendTable(con, "scenario_result", res)

  # Key rate durations of the promise and of each strategy with bonds
  krd_rows <- function(name, cf, tt) {
    k <- key_rate_durations(cf, tt)
    data.frame(portfolio = name, key_year = KEY_RATES, krd = unname(k))
  }
  krd <- krd_rows("promise", L, t)
  for (s in strats) if (sum(s$face) > 0) krd <- rbind(krd, krd_rows(s$name, s$face, s$maturity))
  DBI::dbAppendTable(con, "key_rate", krd)

  con
}

# Run every study query and print the results
run_all_queries <- function(con) {
  for (q in c("liability_profile", "portfolio_summary", "scenario_summary", "tail_loss", "worst_scenarios")) {
    cat("\n==", q, "==\n")
    print(run_sql_file(con, file.path("sql", paste0(q, ".sql"))))
  }
  invisible(NULL)
}
