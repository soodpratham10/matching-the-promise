library(shiny)

# Load the tested engine whether the app runs from app/ or the project root
find_file <- function(...) {
  for (p in c(file.path("..", ...), file.path(...))) if (file.exists(p)) return(p)
  NA
}
source(find_file("r", "promise.R"))
source(find_file("r", "bonds.R"))
source(find_file("r", "matching.R"))
source(find_file("r", "immunize.R"))
source(find_file("r", "storms.R"))

# ---------- The promise (fixed for the game) ----------
liab <- liability_cashflows()
L <- liab$cashflow
tt <- liab$t
PVL <- pv_flat(L, tt, 0.05)
DL <- mac_duration(L, tt, 0.05)
BUDGET <- strategy_budget(L, tt)
CAPITAL <- BUDGET - PVL

money_m <- function(x) paste0(ifelse(x < 0, "-", ""), "$", formatC(abs(x) / 1e6, format = "f", digits = 1, big.mark = ","), "M")
money <- function(x) paste0(ifelse(x < 0, "-", ""), "$", formatC(abs(x), format = "f", digits = 2, big.mark = ","))
tick <- function(ok) if (isTRUE(ok)) span(class = "ok", "\u2713") else span(class = "bad", "\u2717")
note <- p(class = "fineprint", "Illustrative assumptions only. Not calibrated to real data and not investment advice.")

# ---------- The look: a night at sea ----------
PAL <- list(ink = "#0a1a2b", deep = "#10263c", panel = "#132e47", line = "#24476a",
            text = "#e6edf3", muted = "#93a8bd", brass = "#e0b25b", foam = "#5fd4c4",
            storm = "#ff6b6b", amber = "#ffc65c")
STATUS_COL <- c(Safe = PAL$foam, Drifting = PAL$amber, Underwater = PAL$storm)
STATUS_WORD <- c(Safe = "Fair weather", Drifting = "Choppy water", Underwater = "Taking on water")
COMPARE_COL <- c("#7fb3ff", "#c792ea", PAL$foam, "#ff9e64", "#a8a29e")
PLAYER_COL <- PAL$brass

# Base-R charts drawn to match the dark deck
deck_par <- function(mar = c(4, 5, 2.5, 1)) {
  par(bg = PAL$deep, fg = PAL$muted, col.axis = PAL$muted, col.lab = PAL$text, col.main = PAL$text,
      mar = mar, family = "sans", font.main = 1, cex.main = 1.1, las = 1)
}
deck_grid <- function() grid(col = "#ffffff14", lty = 1)

css <- sprintf("
  body { background: %s; color: %s; font-family: 'IBM Plex Sans', sans-serif; }
  h1, h2, h3, h4 { font-family: 'DM Serif Display', serif; letter-spacing: 0.3px; color: %s; }
  .mono, .stat .v, .grade-medal .g { font-family: 'IBM Plex Mono', monospace; }
  .navbar { background: %s !important; border-bottom: 1px solid %s; }
  .navbar-brand { font-family: 'DM Serif Display', serif; font-size: 1.45em; color: %s !important; }
  .navbar .nav-link { color: %s !important; }
  .navbar .nav-link.active { color: %s !important; border-bottom: 2px solid %s; }
  .dropdown-menu { background: %s; border: 1px solid %s; }
  .dropdown-item { color: %s; } .dropdown-item:hover { background: %s; color: %s; }

  .hero { position: relative; overflow: hidden; border-radius: 18px; padding: 34px 34px 70px 34px; margin-bottom: 20px;
          background: radial-gradient(circle at 80%% 10%%, #2a4d73 0%%, %s 55%%, %s 100%%); border: 1px solid %s; }
  .hero h1 { font-size: 3.1em; margin: 0 0 6px 0; }
  .hero .kicker { color: %s; text-transform: uppercase; letter-spacing: 3px; font-size: 0.8em; }
  .hero p.lede { color: %s; font-size: 1.1em; max-width: 720px; }
  .waves { position: absolute; left: 0; right: 0; bottom: 0; height: 60px; opacity: 0.55;
           background: repeating-radial-gradient(circle at 50%% 120%%, transparent 0 18px, %s 19px 21px, transparent 22px 40px);
           background-size: 80px 60px; animation: roll 9s linear infinite; }
  .waves.two { opacity: 0.3; animation-duration: 14s; bottom: -12px; }
  @keyframes roll { from { background-position: 0 0; } to { background-position: 800px 0; } }
  .stats { display: flex; gap: 14px; flex-wrap: wrap; margin-top: 14px; }
  .stat { background: #ffffff0d; border: 1px solid %s; border-radius: 12px; padding: 10px 16px; min-width: 170px; }
  .stat .k { color: %s; font-size: 0.78em; text-transform: uppercase; letter-spacing: 1.5px; }
  .stat .v { color: %s; font-size: 1.35em; }

  .deck { background: %s; border: 1px solid %s; border-radius: 16px; padding: 18px 20px; margin-bottom: 18px; }
  .deck h4 { margin-top: 0; }
  .deck .label { color: %s; text-transform: uppercase; letter-spacing: 2px; font-size: 0.75em; margin-bottom: 4px; }
  .well { background: %s !important; border: 1px solid %s !important; border-radius: 16px !important; }
  .irs--shiny .irs-bar { background: %s; border-color: %s; }
  .irs--shiny .irs-single { background: %s; color: %s; }
  .irs--shiny .irs-handle { border-color: %s; }
  .irs--shiny .irs-line { background: %s; border-color: %s; }
  .irs--shiny .irs-min, .irs--shiny .irs-max, .irs--shiny .irs-grid-text { color: %s; background: transparent; }
  .form-control, .selectize-input, .form-select { background: %s !important; color: %s !important; border-color: %s !important; }
  .selectize-dropdown { background: %s; color: %s; }
  .btn-storm { background: linear-gradient(135deg, %s, #c98a2b); color: %s; border: none; font-weight: 700;
               font-size: 1.15em; padding: 12px 22px; border-radius: 12px; width: 100%%; letter-spacing: 0.5px;
               box-shadow: 0 0 18px #e0b25b55; }
  .btn-storm:hover { filter: brightness(1.08); color: %s; }

  .barometer { border-radius: 16px; padding: 16px 22px; margin-bottom: 18px; background: %s; border: 1px solid %s;
               display: flex; align-items: center; gap: 20px; }
  .barometer .dial { width: 86px; height: 86px; border-radius: 50%%; display: flex; align-items: center; justify-content: center;
                     font-family: 'IBM Plex Mono', monospace; font-size: 1.3em; font-weight: 600; color: %s; }
  .barometer .word { font-family: 'DM Serif Display', serif; font-size: 1.9em; line-height: 1.1; }
  .barometer .sub { color: %s; }

  .gazette { background: #f6efdf; color: #2b2417; border-radius: 6px; padding: 16px 18px; font-family: Georgia, serif;
             box-shadow: 0 8px 24px #00000066; min-height: 300px; }
  .gazette .mast { text-align: center; font-family: 'DM Serif Display', serif; font-size: 1.7em; border-bottom: 3px double #2b2417; }
  .gazette .date { text-align: center; font-style: italic; font-size: 0.82em; margin: 4px 0 10px 0; }
  .gazette .lead { font-weight: bold; font-size: 1.2em; line-height: 1.25; margin-bottom: 8px; }
  .gazette ul { padding-left: 18px; } .gazette li { margin-bottom: 5px; }

  .grade-medal { text-align: center; }
  .grade-medal .g { width: 120px; height: 120px; margin: 6px auto 10px auto; border-radius: 50%%; display: flex;
                    align-items: center; justify-content: center; font-size: 3.4em; font-weight: 700; color: %s;
                    background: radial-gradient(circle at 35%% 30%%, #ffe3a3, %s 55%%, #9c6b1f 100%%);
                    box-shadow: 0 0 0 6px #ffffff10, 0 0 30px #e0b25b66; }
  .grade-medal .title { font-family: 'DM Serif Display', serif; font-size: 1.5em; color: %s; }
  .badge-survivor { display: inline-block; margin-top: 8px; padding: 5px 12px; border-radius: 20px; background: #5fd4c422;
                    border: 1px solid %s; color: %s; }
  .table { color: %s; } .table > :not(caption) > * > * { background: transparent; color: %s; border-color: %s; }
  .ok { color: %s; font-weight: 700; } .bad { color: %s; font-weight: 700; }
  .warn { color: %s; font-weight: 700; }
  .fineprint { color: %s; font-size: 0.82em; font-style: italic; margin-top: 10px; }
  a { color: %s; }
",
  PAL$ink, PAL$text, PAL$text,
  PAL$ink, PAL$line, PAL$brass,
  PAL$muted, PAL$text, PAL$brass,
  PAL$deep, PAL$line,
  PAL$text, PAL$panel, PAL$brass,
  PAL$deep, PAL$ink, PAL$line,
  PAL$brass, PAL$muted,
  PAL$foam,
  PAL$line, PAL$muted, PAL$text,
  PAL$deep, PAL$line, PAL$brass,
  PAL$deep, PAL$line,
  PAL$brass, PAL$brass, PAL$brass, PAL$ink, PAL$brass, PAL$line, PAL$line, PAL$muted,
  PAL$panel, PAL$text, PAL$line, PAL$panel, PAL$text,
  PAL$brass, PAL$ink, PAL$ink,
  PAL$deep, PAL$line, PAL$ink, PAL$muted,
  PAL$ink, PAL$brass, PAL$brass,
  PAL$foam, PAL$foam,
  PAL$text, PAL$text, PAL$line,
  PAL$foam, PAL$storm, PAL$storm,
  PAL$muted, PAL$foam)

head_tags <- tags$head(
  tags$link(rel = "stylesheet",
            href = "https://fonts.googleapis.com/css2?family=DM+Serif+Display&family=IBM+Plex+Mono:wght@400;600&family=IBM+Plex+Sans:wght@400;600&display=swap"),
  tags$style(HTML(css))
)

deck <- function(label, ...) div(class = "deck", div(class = "label", label), ...)
stat <- function(k, v) div(class = "stat", div(class = "k", k), div(class = "v", v))

bucket_ids <- paste0("b", GAME_BUCKETS)
bucket_default <- c(0, 20, 50, 20, 10, 0)

# ---------- Play tab ----------
tab_play <- tabPanel("The Storm",
  div(class = "hero",
    div(class = "kicker", "Prairie Promise Annuities \u00B7 closed block \u00B7 night watch"),
    h1("\u26C8 The Rate Storm"),
    p(class = "lede", "Ten thousand retirees have been promised $10,000 a year for life. The money is in the vault.
      You are the investment actuary: spend it on bonds, then sail it through twenty years of interest rates.
      Keep the surplus above water and every cheque gets paid."),
    div(class = "stats",
      stat("The promise today", money_m(PVL)),
      stat("Its duration", sprintf("%.2f years", DL)),
      stat("Your budget", money_m(BUDGET)),
      stat("Capital cushion", money_m(CAPITAL))),
    div(class = "waves"), div(class = "waves two")
  ),
  fluidRow(
    column(4,
      deck("1 \u00B7 Load the hold",
        h4("Government strips"),
        lapply(seq_along(GAME_BUCKETS), function(k)
          sliderInput(bucket_ids[k], sprintf("%d-year strips (%% of budget)", GAME_BUCKETS[k]),
                      min = 0, max = 100, value = bucket_default[k], step = 5)),
        uiOutput("alloc_note")),
      deck("2 \u00B7 Check the trim", htmlOutput("profile")),
      deck("3 \u00B7 Choose the weather",
        selectInput("storm", NULL, choices = STORMS, selected = "steepener"),
        conditionalPanel("input.storm == 'random'",
          numericInput("seed", "Game number (same number, same storm)", value = 7, min = 1, step = 1)),
        actionButton("go", "\u26C8  Unleash the storm", class = "btn-storm"))
    ),
    column(8,
      uiOutput("meter"),
      deck("The voyage", plotOutput("surplus_plot", height = "330px")),
      deck("The weather", plotOutput("rate_plot", height = "190px")),
      fluidRow(
        column(7, uiOutput("newspaper")),
        column(5, uiOutput("report"))
      ),
      br(),
      deck("The same storm, every textbook strategy", tableOutput("compare")),
      note
    )
  )
)

# ---------- How it works: Chapter 1 ----------
tab_ch1 <- tabPanel("Chapter 1 \u00B7 The Promise",
  fluidRow(
    column(4, deck("Assumptions",
      numericInput("c1_n", "Retirees", 10000, min = 1, step = 1000),
      numericInput("c1_pay", "Annual payment ($)", 10000, min = 0, step = 1000),
      sliderInput("c1_age", "Age at valuation", 55, 85, 65),
      sliderInput("c1_i", "Valuation rate", 0.01, 0.10, 0.05, step = 0.0025),
      sliderInput("c1_shift", "Rate shift to approximate", -0.03, 0.03, 0.01, step = 0.0025))),
    column(8,
      deck("How heavy is the promise?",
        p("The expected payment in year t is retirees \u00D7 payment \u00D7 the chance of surviving t years."),
        tableOutput("c1_profile")),
      deck("The promise, year by year", plotOutput("c1_plot", height = "310px")),
      deck("How good are the duration approximations?", tableOutput("c1_approx")),
      note)
  )
)

# ---------- Chapter 2 ----------
tab_ch2 <- tabPanel("Chapter 2 \u00B7 Exact Matching",
  fluidRow(
    column(4, deck("The matching bonds",
      sliderInput("c2_r", "Coupon rate", 0.01, 0.08, 0.04, step = 0.005),
      sliderInput("c2_max", "Longest coupon bond (years)", 10, 45, 30, step = 1),
      p("Work backwards from the last year: each bond's face covers its year's payment after the coupons from every longer bond."))),
    column(8,
      deck("A bond for every cheque", htmlOutput("c2_summary"), plotOutput("c2_plot", height = "310px")),
      deck("Year by year", tableOutput("c2_table")),
      note)
  )
)

# ---------- Chapter 3 ----------
tab_ch3 <- tabPanel("Chapter 3 \u00B7 Immunization",
  fluidRow(
    column(4, deck("Pick two strips",
      selectInput("c3_m1", "Short strip (years)", choices = STRIP_SHELF[STRIP_SHELF < DL], selected = 2),
      selectInput("c3_m2", "Long strip (years)", choices = STRIP_SHELF[STRIP_SHELF > DL], selected = 30),
      p("Match the PV and duration of the promise. Redington also needs more convexity than the promise."),
      p(strong("Try 5 and 20:"), " the duration matches, but the convexity falls short."))),
    column(8,
      deck("The pair", tableOutput("c3_pair"), htmlOutput("c3_checks")),
      deck("Surplus if rates jump today to a new flat level", plotOutput("c3_plot", height = "340px")),
      deck("Full immunization: every payment bracketed",
        p("Each payment is split between the shelf strips just before and just after it, so no parallel shift of any size creates a loss."),
        tableOutput("c3_full")),
      note)
  )
)

# ---------- Chapter 4 ----------
tab_ch4 <- tabPanel("Chapter 4 \u00B7 Rate Storms",
  fluidRow(
    column(4, deck("The shocks",
      sliderInput("c4_sdl", "Standard deviation of level shocks", 0, 0.03, 0.01, step = 0.0025),
      sliderInput("c4_sds", "Standard deviation of slope shocks", 0, 0.02, 0.005, step = 0.0025),
      numericInput("c4_seed", "Seed", 2026, min = 1),
      p("Your portfolio here is the one loaded on The Storm tab."))),
    column(8,
      deck("Key rate durations: where on the curve each portfolio is exposed", plotOutput("c4_krd", height = "310px")),
      deck("1,000 instant shocks to the level and slope of the curve", plotOutput("c4_hist", height = "310px"),
           tableOutput("c4_table")),
      note)
  )
)

tab_about <- tabPanel("About",
  fluidRow(column(8, offset = 2,
    deck("About the voyage",
      h3("Matching the Promise"),
      p("A closed block of annuities has made a promise: 10,000 retirees will be paid every year for as long as they live.
         The money is already invested. This game asks one question: which bonds keep that promise safe when interest rates move?"),
      p("Every number comes from a tested R engine (130 tests), cross-checked in SQL and rebuilt independently in Excel."),
      p(a("Source code on GitHub", href = "https://github.com/soodpratham10/matching-the-promise", target = "_blank")),
      p("Built by Pratham Sood, Actuarial Mathematics and Statistics, University of Manitoba."),
      p(em("Companion project: "), a("The Odds of a Lifetime", href = "https://soodpratham10.shinyapps.io/odds-of-a-lifetime/", target = "_blank")),
      note)
  ))
)

ui <- navbarPage(
  title = "Matching the Promise",
  header = head_tags,
  theme = bslib::bs_theme(version = 5, bg = PAL$ink, fg = PAL$text, primary = PAL$brass, secondary = PAL$foam,
                          base_font = "IBM Plex Sans, sans-serif", heading_font = "DM Serif Display, serif"),
  tab_play,
  navbarMenu("How it works", tab_ch1, tab_ch2, tab_ch3, tab_ch4),
  tab_about
)

server <- function(input, output, session) {

  # ---------- Play ----------
  alloc <- reactive(sapply(bucket_ids, function(id) input[[id]]) / 100)
  alloc_ok <- reactive(sum(alloc()) <= 1 + 1e-9)
  player <- reactive({
    req(alloc_ok())
    player_strategy(alloc(), L, tt)
  })

  output$alloc_note <- renderUI({
    s <- sum(alloc())
    if (s > 1 + 1e-9) {
      p(class = "warn", sprintf("Overloaded: %.0f%% of the budget. Bring it down to 100%% or less.", 100 * s))
    } else {
      p(sprintf("Left in cash, earning the one-year rate: %.0f%% (%s)", 100 * (1 - s), money_m(BUDGET * (1 - s))))
    }
  })

  output$profile <- renderUI({
    req(alloc_ok())
    p_ <- player()
    if (sum(p_$face) == 0) return(p(em("No bonds loaded yet: everything is in cash.")))
    # cash counts as a one-year asset in the profile
    cf <- c(p_$face, p_$cash * 1.05); m <- c(p_$maturity, 1)
    chk <- redington_check(cf, m, L, tt, 0.05, tol = 0.01)
    tagList(
      tags$table(class = "table table-sm",
        tags$tr(tags$th(""), tags$th("Your hold"), tags$th("The promise")),
        tags$tr(tags$td("Value"), tags$td(class = "mono", money_m(chk$pv_assets)), tags$td(class = "mono", money_m(chk$pv_liabilities))),
        tags$tr(tags$td("Duration"), tags$td(class = "mono", sprintf("%.2f", chk$duration_assets)), tags$td(class = "mono", sprintf("%.2f", chk$duration_liabilities))),
        tags$tr(tags$td("Convexity"), tags$td(class = "mono", sprintf("%.1f", chk$convexity_assets)), tags$td(class = "mono", sprintf("%.1f", chk$convexity_liabilities)))),
      p("Redington: duration within 1% ", tick(chk$duration_match), " \u00B7 more convexity ", tick(chk$convexity_ok)))
  })

  result <- eventReactive(input$go, {
    validate(need(alloc_ok(), "Bring your allocation down to 100% or less."))
    seed <- if (is.null(input$seed) || is.na(input$seed)) 1 else input$seed
    path <- storm_path(input$storm, seed = seed)
    sim <- simulate_storm(player(), L, tt, path)
    others <- lapply(names(STRATEGY_LABELS), function(s) simulate_storm(make_strategy(s, L, tt), L, tt, path))
    list(path = path, sim = sim, others = others, storm = input$storm, seed = seed,
         storm_name = names(STORMS)[STORMS == input$storm],
         compare = compare_strategies(L, tt, path, player = player()))
  })

  output$meter <- renderUI({
    if (input$go == 0) {
      return(div(class = "barometer",
        div(class = "dial", style = sprintf("border: 4px solid %s;", PAL$muted), "?"),
        div(div(class = "word", "Waiting for weather"),
            div(class = "sub", "Load the hold, choose the weather, and unleash the storm."))))
    }
    r <- result(); st <- storm_status(r$sim)
    final <- st[length(st)]
    pct <- 100 * r$sim$surplus[nrow(r$sim)] / r$sim$surplus[1]
    div(class = "barometer", style = sprintf("border-color: %s; box-shadow: 0 0 22px %s44;", STATUS_COL[final], STATUS_COL[final]),
      div(class = "dial", style = sprintf("border: 4px solid %s; box-shadow: inset 0 0 18px %s55;", STATUS_COL[final], STATUS_COL[final]),
          sprintf("%.0f%%", pct)),
      div(div(class = "word", style = sprintf("color: %s;", STATUS_COL[final]), sprintf("%s \u00B7 %s", final, STATUS_WORD[final])),
          div(class = "sub", sprintf("%s, 20 years on. Surplus %s, from %s at the start. Lowest point %s in year %d.",
                                     r$storm_name, money_m(r$sim$surplus[nrow(r$sim)]), money_m(r$sim$surplus[1]),
                                     money_m(min(r$sim$surplus)), r$sim$year[which.min(r$sim$surplus)]))))
  })

  output$surplus_plot <- renderPlot({
    req(input$go > 0)
    r <- result()
    all_s <- c(r$sim$surplus, unlist(lapply(r$others, function(o) o$surplus)))
    yl <- range(all_s / 1e6, 0)
    deck_par()
    plot(r$sim$year, r$sim$surplus / 1e6, type = "n", ylim = yl, xlab = "Year", ylab = "Surplus ($M)",
         main = "Everything the fund owns, minus the value of the promise")
    rect(-5, yl[1] - 1e6, 30, 0, col = "#ff6b6b1f", border = NA)
    deck_grid()
    for (k in seq_along(r$others)) lines(r$others[[k]]$year, r$others[[k]]$surplus / 1e6, col = COMPARE_COL[k], lty = 2, lwd = 1.6)
    lines(r$sim$year, r$sim$surplus / 1e6, lwd = 8, col = "#e0b25b33")
    lines(r$sim$year, r$sim$surplus / 1e6, lwd = 3.5, col = PLAYER_COL)
    abline(h = 0, col = PAL$storm, lwd = 1.5)
    text(0, yl[1], "below the line: underwater", adj = c(0, -0.6), col = PAL$storm, cex = 0.8)
    legend("topleft", c("Your hold", unname(STRATEGY_LABELS)), col = c(PLAYER_COL, COMPARE_COL),
           lty = c(1, rep(2, 5)), lwd = c(3.5, rep(1.6, 5)), bty = "n", cex = 0.85, text.col = PAL$text)
  }, bg = PAL$deep)

  output$rate_plot <- renderPlot({
    req(input$go > 0)
    r <- result()
    s2 <- spot_curve(2, r$path$level, r$path$slope); s30 <- spot_curve(30, r$path$level, r$path$slope)
    deck_par(c(4, 5, 1, 1))
    plot(r$path$year, 100 * r$sim$ten_year_rate, type = "n",
         ylim = range(100 * c(s2, s30, r$sim$ten_year_rate)), xlab = "Year", ylab = "Rate (%)")
    deck_grid()
    lines(r$path$year, 100 * s2, col = "#ff9e64", lwd = 2.5)
    lines(r$path$year, 100 * r$sim$ten_year_rate, col = "#7fb3ff", lwd = 2.5)
    lines(r$path$year, 100 * s30, col = "#c792ea", lwd = 2.5)
    legend("topleft", c("2-year", "10-year", "30-year"), col = c("#ff9e64", "#7fb3ff", "#c792ea"), lwd = 2.5,
           bty = "n", horiz = TRUE, text.col = PAL$text, cex = 0.85)
  }, bg = PAL$deep)

  output$newspaper <- renderUI({
    req(input$go > 0)
    r <- result()
    h <- storm_headlines(r$sim)
    lead <- if (length(h) == 0) "A quiet twenty years: the cheques went out and nobody noticed." else sub("^Year [0-9]+: ", "", h[1])
    rest <- if (length(h) > 1) h[-1] else character(0)
    div(class = "gazette",
      div(class = "mast", "The Yield Curve Gazette"),
      div(class = "date", sprintf("Special edition \u00B7 %s \u00B7 twenty years in review", r$storm_name)),
      div(class = "lead", lead),
      if (length(h) > 0) p(em(sub(":.*$", "", h[1]))),
      if (length(rest) > 0) tags$ul(lapply(rest, tags$li)))
  })

  output$report <- renderUI({
    req(input$go > 0)
    r <- result()
    sc <- storm_score(r$sim); g <- storm_grade(sc)
    survived <- all(storm_status(r$sim) != "Underwater")
    div(class = "deck grade-medal",
      div(class = "label", "Captain's report"),
      div(class = "g", g),
      div(class = "title", STORM_TITLES[[g]]),
      p(sprintf("Lowest surplus: %.0f%% of your starting capital.", 100 * sc)),
      if (survived && r$storm != "calm") div(class = "badge-survivor", "\U0001F3C6 Storm Survivor \u00B7 never underwater"),
      if (r$storm == "random") p(class = "fineprint", sprintf("Game number %.0f. Share it to replay this exact storm.", r$seed)))
  })

  output$compare <- renderTable({
    req(input$go > 0)
    tab <- result()$compare
    data.frame(Strategy = tab$strategy, `Lowest surplus` = money_m(tab$worst_surplus),
               `Surplus at year 20` = money_m(tab$final_surplus),
               `Lowest as % of capital` = sprintf("%.0f%%", 100 * tab$score), Grade = tab$grade,
               check.names = FALSE)
  })

  # ---------- Chapter 1 ----------
  c1 <- reactive({
    lc <- liability_cashflows(n_lives = input$c1_n, payment = input$c1_pay, age = input$c1_age)
    list(lc = lc, rp = rate_profile(lc$cashflow, lc$t, input$c1_i))
  })
  output$c1_profile <- renderTable({
    rp <- c1()$rp
    data.frame(Measure = c("Present value", "Macaulay duration", "Modified duration", "Macaulay convexity", "Modified convexity"),
               Value = c(money(rp$pv), sprintf("%.4f", rp$mac_duration), sprintf("%.4f", rp$mod_duration),
                         sprintf("%.4f", rp$mac_convexity), sprintf("%.4f", rp$mod_convexity)))
  })
  output$c1_plot <- renderPlot({
    lc <- c1()$lc; d <- c1()$rp$mac_duration
    deck_par()
    barplot(lc$cashflow / 1e6, names.arg = lc$t, col = PAL$foam, border = NA, space = 0.15,
            xlab = "Year", ylab = "Expected payment ($M)", main = "Each bar is one year of cheques")
    abline(v = d * 1.15 - 0.5, col = PAL$brass, lwd = 3)
    legend("topright", sprintf("Macaulay duration %.2f years", d), col = PAL$brass, lwd = 3, bty = "n", text.col = PAL$text)
  }, bg = PAL$deep)
  output$c1_approx <- renderTable({
    lc <- c1()$lc; i0 <- input$c1_i; i1 <- i0 + input$c1_shift
    ex <- pv_flat(lc$cashflow, lc$t, i1)
    ap <- sapply(c("macaulay", "modified", "convexity"), function(m) approx_pv(lc$cashflow, lc$t, i0, i1, m))
    data.frame(Method = c("Exact", "Macaulay duration", "Modified duration", "Modified duration + convexity"),
               `PV at new rate` = money(c(ex, ap)), `Error` = money(c(0, ap - ex)),
               `Error (%)` = sprintf("%.3f%%", 100 * (c(ex, ap) - ex) / ex), check.names = FALSE)
  })

  # ---------- Chapter 2 ----------
  c2 <- reactive({
    ded <- suppressWarnings(dedicate_portfolio(L, input$c2_r, input$c2_max))
    list(ded = ded, tab = dedication_table(ded, L))
  })
  output$c2_summary <- renderUI({
    ded <- c2()$ded
    tagList(
      div(class = "stats",
        stat("Coupon bonds", length(ded$coupon_face)),
        stat("Strips", length(ded$strip_face)),
        stat("Cost at 5%", money_m(dedication_cost(ded, 0.05))),
        stat("Largest yearly gap", money(max(abs(ded$gap))))),
      br(),
      if (any(ded$coupon_face < 0)) p(class = "warn", "Some faces are negative: the coupons overshoot those years, so you would have to sell bonds short.")
      else p("Every year is matched exactly, so no rate move can touch the surplus. The cost is exactly the value of the promise."))
  })
  output$c2_plot <- renderPlot({
    tab <- c2()$tab
    deck_par()
    m <- rbind(tab$coupons, tab$redemptions, tab$strips) / 1e6
    barplot(m, names.arg = tab$year, col = c("#2f6f8f", PAL$foam, PAL$brass), border = NA, space = 0.15,
            xlab = "Year", ylab = "$M", main = "Bond cash flows stacked against each year's cheques")
    points((tab$year - 1) * 1.15 + 0.65, tab$liability / 1e6, pch = 21, bg = PAL$text, col = PAL$ink, cex = 0.9)
    legend("topright", c("Coupons", "Bonds maturing", "Strips", "The promise"), fill = c("#2f6f8f", PAL$foam, PAL$brass, NA),
           border = NA, pch = c(NA, NA, NA, 21), pt.bg = PAL$text, bty = "n", text.col = PAL$text)
  }, bg = PAL$deep)
  output$c2_table <- renderTable({
    tab <- c2()$tab
    data.frame(Year = tab$year, Promise = money(tab$liability), Coupons = money(tab$coupons),
               `Bonds maturing` = money(tab$redemptions), Strips = money(tab$strips), Gap = money(tab$gap),
               check.names = FALSE)
  })

  # ---------- Chapter 3 ----------
  c3 <- reactive({
    m1 <- as.numeric(input$c3_m1); m2 <- as.numeric(input$c3_m2)
    pr <- redington_pair(L, tt, 0.05, m1, m2)
    list(pr = pr, chk = redington_check(pr$face, pr$maturity, L, tt, 0.05),
         full = full_immunization(L, tt, 0.05))
  })
  output$c3_pair <- renderTable({
    pr <- c3()$pr
    data.frame(Strip = paste(pr$maturity, "years"), `Cost today` = money(pr$cost), `Face at maturity` = money(pr$face),
               check.names = FALSE)
  })
  output$c3_checks <- renderUI({
    ch <- c3()$chk
    tagList(
      tags$ol(
        tags$li("PV matches ", tick(ch$pv_match), span(class = "mono", paste0(" ", money(ch$pv_assets)))),
        tags$li("Duration matches ", tick(ch$duration_match), span(class = "mono", sprintf(" %.4f years", ch$duration_assets))),
        tags$li("More convexity than the promise ", tick(ch$convexity_ok),
                span(class = "mono", sprintf(" %.2f vs %.2f", ch$convexity_assets, ch$convexity_liabilities)))),
      if (ch$immunized) p(class = "ok", "Redington immunized: small parallel shifts cannot create a loss.")
      else p(class = "bad", "Not immunized: duration alone is not enough. This pair loses money when rates move either way."))
  })
  output$c3_plot <- renderPlot({
    pr <- c3()$pr; fu <- c3()$full
    rates <- seq(0.01, 0.10, by = 0.001)
    sp <- surplus_curve(pr$face, pr$maturity, L, tt, rates)
    sf <- surplus_curve(fu$face, fu$maturity, L, tt, rates)
    deck_par()
    plot(100 * rates, sp$surplus / 1e6, type = "n", ylim = range(c(sp$surplus, sf$surplus, 0) / 1e6),
         xlab = "Flat interest rate (%)", ylab = "Surplus ($M)")
    deck_grid()
    lines(100 * rates, sp$surplus / 1e6, lwd = 3, col = "#c792ea")
    lines(100 * rates, sf$surplus / 1e6, lwd = 3, col = PAL$foam)
    abline(h = 0, col = PAL$storm); abline(v = 5, lty = 3, col = PAL$muted)
    legend("top", c(sprintf("%s and %s year strips", input$c3_m1, input$c3_m2), "Full immunization"),
           col = c("#c792ea", PAL$foam), lwd = 3, bty = "n", text.col = PAL$text)
  }, bg = PAL$deep)
  output$c3_full <- renderTable({
    fu <- c3()$full
    data.frame(Strip = paste(fu$maturity, "years"), `Cost today` = money(fu$cost), `Face at maturity` = money(fu$face),
               check.names = FALSE)
  })

  # ---------- Chapter 4 ----------
  c4_strats <- reactive({
    s <- list(redington = make_strategy("redington", L, tt), full = make_strategy("full", L, tt))
    if (alloc_ok() && sum(alloc()) > 0) s$player <- player()
    s
  })
  output$c4_krd <- renderPlot({
    s <- c4_strats()
    k <- rbind(Promise = key_rate_durations(L, tt),
               `Redington barbell` = key_rate_durations(s$redington$face, s$redington$maturity),
               `Full immunization` = key_rate_durations(s$full$face, s$full$maturity))
    if (!is.null(s$player)) k <- rbind(k, `Your hold` = key_rate_durations(s$player$face, s$player$maturity))
    deck_par()
    barplot(k, beside = TRUE, col = c(PAL$text, "#c792ea", PAL$foam, PAL$brass)[seq_len(nrow(k))], border = NA,
            xlab = "Key rate", ylab = "Key rate duration", legend.text = rownames(k),
            args.legend = list(bty = "n", text.col = PAL$text))
  }, bg = PAL$deep)
  c4_res <- reactive({
    sh <- random_shocks(1000, input$c4_sdl, input$c4_sds, input$c4_seed)
    s <- c4_strats()
    sapply(s, function(st) st$cash + mapply(function(lv, sl) shock_surplus(st$face, st$maturity, L, tt, lv, sl), sh$level, sh$slope))
  })
  output$c4_hist <- renderPlot({
    r <- c4_res()
    br <- pretty(range(r / 1e6), 40)
    deck_par()
    cols <- c(redington = "#c792ea99", full = "#5fd4c499", player = "#e0b25b99")
    hist(r[, 1] / 1e6, breaks = br, col = cols[colnames(r)[1]], border = NA, main = "Surplus after the shock",
         xlab = "Surplus ($M)", ylim = c(0, 1000))
    for (k in 2:ncol(r)) hist(r[, k] / 1e6, breaks = br, col = cols[colnames(r)[k]], border = NA, add = TRUE)
    abline(v = 0, col = PAL$storm, lwd = 2)
    legend("topright", c(redington = "Redington barbell", full = "Full immunization", player = "Your hold")[colnames(r)],
           fill = cols[colnames(r)], border = NA, bty = "n", text.col = PAL$text)
  }, bg = PAL$deep)
  output$c4_table <- renderTable({
    r <- c4_res()
    lab <- c(redington = "Redington barbell", full = "Full immunization", player = "Your hold")
    data.frame(Strategy = lab[colnames(r)], `Average surplus` = money_m(colMeans(r)),
               `5th percentile` = money_m(apply(r, 2, quantile, 0.05)),
               `Chance surplus is negative` = sprintf("%.1f%%", 100 * colMeans(r < 0)), check.names = FALSE)
  })
}

shinyApp(ui, server)
