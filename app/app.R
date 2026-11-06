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
CVX <- mac_convexity(L, tt, 0.05)
BUDGET <- strategy_budget(L, tt)
CAPITAL <- BUDGET - PVL

money_m <- function(x) paste0(ifelse(x < 0, "-", ""), "$", formatC(abs(x) / 1e6, format = "f", digits = 1, big.mark = ","), "M")
money <- function(x) paste0(ifelse(x < 0, "-", ""), "$", formatC(abs(x), format = "f", digits = 2, big.mark = ","))
tick <- function(ok) if (isTRUE(ok)) "\u2713" else "\u2717"
note <- p(em("Illustrative assumptions only. Not calibrated to real data and not investment advice."))

STATUS_COL <- c(Safe = "#2e7d32", Drifting = "#f9a825", Underwater = "#c62828")
STATUS_DOT <- c(Safe = "\U0001F7E2", Drifting = "\U0001F7E1", Underwater = "\U0001F534")
COMPARE_COL <- c("#1565c0", "#6a1b9a", "#00897b", "#ef6c00", "#8d6e63")

bucket_ids <- paste0("b", GAME_BUCKETS)
bucket_default <- c(0, 20, 50, 20, 10, 0)

# ---------- Play tab ----------
tab_play <- tabPanel("Play",
  sidebarLayout(
    sidebarPanel(width = 4,
      h4("The promise"),
      p(sprintf("10,000 retirees aged 65, each paid $10,000 a year for life. Value today: %s, duration %.2f years.",
                money_m(PVL), DL)),
      p(sprintf("Your budget is %s: the value of the promise plus %s of capital.", money_m(BUDGET), money_m(CAPITAL))),
      h4("Spend it on government strips"),
      lapply(seq_along(GAME_BUCKETS), function(k)
        sliderInput(bucket_ids[k], sprintf("%d-year strips (%% of budget)", GAME_BUCKETS[k]),
                    min = 0, max = 100, value = bucket_default[k], step = 5)),
      uiOutput("alloc_note"),
      htmlOutput("profile"),
      hr(),
      h4("Choose the storm"),
      selectInput("storm", NULL, choices = STORMS, selected = "random"),
      conditionalPanel("input.storm == 'random'",
        numericInput("seed", "Game number (same number, same storm)", value = 7, min = 1, step = 1)),
      actionButton("go", "\u26C8 Unleash the storm", class = "btn-primary btn-lg")
    ),
    mainPanel(width = 8,
      uiOutput("meter"),
      plotOutput("surplus_plot", height = "340px"),
      plotOutput("rate_plot", height = "200px"),
      fluidRow(
        column(6, uiOutput("newspaper")),
        column(6, uiOutput("report"))
      ),
      h4("The same storm, every textbook strategy"),
      tableOutput("compare"),
      note
    )
  )
)

# ---------- How it works: Chapter 1 ----------
tab_ch1 <- tabPanel("Chapter 1: The Promise",
  sidebarLayout(
    sidebarPanel(
      numericInput("c1_n", "Retirees", 10000, min = 1, step = 1000),
      numericInput("c1_pay", "Annual payment ($)", 10000, min = 0, step = 1000),
      sliderInput("c1_age", "Age at valuation", 55, 85, 65),
      sliderInput("c1_i", "Valuation rate", 0.01, 0.10, 0.05, step = 0.0025),
      sliderInput("c1_shift", "Rate shift to approximate", -0.03, 0.03, 0.01, step = 0.0025)
    ),
    mainPanel(
      p(em("The expected payment in year t is the number of retirees times the payment times the chance of surviving t years.")),
      tableOutput("c1_profile"),
      plotOutput("c1_plot", height = "320px"),
      h4("How good are the duration approximations?"),
      tableOutput("c1_approx"),
      note
    )
  )
)

# ---------- Chapter 2 ----------
tab_ch2 <- tabPanel("Chapter 2: Exact Matching",
  sidebarLayout(
    sidebarPanel(
      sliderInput("c2_r", "Coupon rate of the matching bonds", 0.01, 0.08, 0.04, step = 0.005),
      sliderInput("c2_max", "Longest coupon bond (years)", 10, 45, 30, step = 1),
      p("Work backwards from the last year: each bond's face covers its year's payment after the coupons from every longer bond.")
    ),
    mainPanel(
      htmlOutput("c2_summary"),
      plotOutput("c2_plot", height = "320px"),
      tableOutput("c2_table"),
      note
    )
  )
)

# ---------- Chapter 3 ----------
tab_ch3 <- tabPanel("Chapter 3: Immunization",
  sidebarLayout(
    sidebarPanel(
      selectInput("c3_m1", "Short strip (years)", choices = STRIP_SHELF[STRIP_SHELF < DL], selected = 2),
      selectInput("c3_m2", "Long strip (years)", choices = STRIP_SHELF[STRIP_SHELF > DL], selected = 30),
      p("Match the PV and the duration of the promise with two strips. Redington also needs more convexity than the promise."),
      p("Try 5 and 20: the duration matches, but the convexity falls short.")
    ),
    mainPanel(
      tableOutput("c3_pair"),
      htmlOutput("c3_checks"),
      plotOutput("c3_plot", height = "360px"),
      p(em("Full immunization buys the shelf strips on either side of every payment, so no parallel shift of any size creates a loss.")),
      tableOutput("c3_full"),
      note
    )
  )
)

# ---------- Chapter 4 ----------
tab_ch4 <- tabPanel("Chapter 4: Rate Storms",
  sidebarLayout(
    sidebarPanel(
      sliderInput("c4_sdl", "Standard deviation of level shocks", 0, 0.03, 0.01, step = 0.0025),
      sliderInput("c4_sds", "Standard deviation of slope shocks", 0, 0.02, 0.005, step = 0.0025),
      numericInput("c4_seed", "Seed", 2026, min = 1),
      p("Your portfolio here is the one on the Play tab.")
    ),
    mainPanel(
      h4("Key rate durations: where on the curve each portfolio is exposed"),
      plotOutput("c4_krd", height = "320px"),
      h4("1,000 instant shocks to the level and slope of the curve"),
      plotOutput("c4_hist", height = "320px"),
      tableOutput("c4_table"),
      note
    )
  )
)

tab_about <- tabPanel("About",
  fluidRow(column(8, offset = 2,
    h3("Matching the Promise"),
    p("A closed block of annuities has made a promise: 10,000 retirees will be paid every year for as long as they live.
       The money is already invested. This game asks one question: which bonds keep that promise safe when interest rates move?"),
    p("Every number comes from a tested R engine (130 tests), cross-checked in SQL and rebuilt independently in Excel."),
    p(a("Source code on GitHub", href = "https://github.com/soodpratham10/matching-the-promise", target = "_blank")),
    p("Built by Pratham Sood, Actuarial Mathematics and Statistics, University of Manitoba."),
    note
  ))
)

ui <- navbarPage("Matching the Promise",
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
      div(style = "color:#c62828;font-weight:bold;",
          sprintf("You have allocated %.0f%% of the budget. Bring it down to 100%% or less.", 100 * s))
    } else {
      p(sprintf("Left in cash (earning the one-year rate): %.0f%% = %s", 100 * (1 - s), money_m(BUDGET * (1 - s))))
    }
  })

  output$profile <- renderUI({
    req(alloc_ok())
    p_ <- player()
    if (sum(p_$face) == 0) return(p(em("No bonds bought yet: everything is in cash.")))
    # cash counts as a one-year asset in the profile
    cf <- c(p_$face, p_$cash * 1.05); m <- c(p_$maturity, 1)
    chk <- redington_check(cf, m, L, tt, 0.05, tol = 0.01)
    HTML(sprintf(
      "<table class='table table-condensed'><tr><th></th><th>Your bonds</th><th>The promise</th></tr>
       <tr><td>Value</td><td>%s</td><td>%s</td></tr>
       <tr><td>Duration</td><td>%.2f</td><td>%.2f</td></tr>
       <tr><td>Convexity</td><td>%.1f</td><td>%.1f</td></tr></table>
       <p>Redington check: duration within 1%% %s, more convexity %s</p>",
      money_m(chk$pv_assets), money_m(chk$pv_liabilities), chk$duration_assets, chk$duration_liabilities,
      chk$convexity_assets, chk$convexity_liabilities, tick(chk$duration_match), tick(chk$convexity_ok)))
  })

  result <- eventReactive(input$go, {
    validate(need(alloc_ok(), "Bring your allocation down to 100% or less."))
    seed <- if (is.null(input$seed) || is.na(input$seed)) 1 else input$seed
    path <- storm_path(input$storm, seed = seed)
    sim <- simulate_storm(player(), L, tt, path)
    others <- lapply(names(STRATEGY_LABELS), function(s) simulate_storm(make_strategy(s, L, tt), L, tt, path))
    list(path = path, sim = sim, others = others, storm = input$storm, seed = seed,
         compare = compare_strategies(L, tt, path, player = player()))
  })

  output$meter <- renderUI({
    if (input$go == 0) {
      return(div(style = "padding:16px;background:#f4f6f6;border-radius:8px;",
        h3("You are the investment actuary of Prairie Promise Annuities."),
        p("Spend the budget on the left, choose a storm, and press the button. Twenty years of interest rates will
           test whether your bonds can keep paying the cheques. Rates move, the bonds and the promise both change value,
           and the surplus between them is what keeps the fund alive.")))
    }
    r <- result(); st <- storm_status(r$sim)
    final <- st[length(st)]; worst <- min(r$sim$surplus)
    div(style = sprintf("padding:12px;border-radius:8px;border:3px solid %s;", STATUS_COL[final]),
      h3(sprintf("%s %s after 20 years", STATUS_DOT[final], final)),
      p(sprintf("Surplus now %s (started at %s). Worst point: %s in year %d.",
                money_m(r$sim$surplus[nrow(r$sim)]), money_m(r$sim$surplus[1]), money_m(worst),
                r$sim$year[which.min(r$sim$surplus)])))
  })

  output$surplus_plot <- renderPlot({
    req(input$go > 0)
    r <- result()
    all_s <- c(r$sim$surplus, unlist(lapply(r$others, function(o) o$surplus)))
    yl <- range(all_s / 1e6, 0)
    par(mar = c(4, 5, 2, 1))
    plot(r$sim$year, r$sim$surplus / 1e6, type = "n", ylim = yl, xlab = "Year", ylab = "Surplus ($M)",
         main = "Surplus: everything the fund owns minus the value of the promise")
    rect(-5, yl[1] - 1e6, 30, 0, col = "#fdecea", border = NA)
    for (k in seq_along(r$others)) lines(r$others[[k]]$year, r$others[[k]]$surplus / 1e6, col = COMPARE_COL[k], lty = 2)
    lines(r$sim$year, r$sim$surplus / 1e6, lwd = 4, col = "black")
    abline(h = 0, col = "#c62828")
    legend("topleft", c("Your portfolio", unname(STRATEGY_LABELS)), col = c("black", COMPARE_COL),
           lty = c(1, rep(2, 5)), lwd = c(4, rep(1, 5)), bty = "n", cex = 0.85)
  })

  output$rate_plot <- renderPlot({
    req(input$go > 0)
    r <- result()
    s2 <- spot_curve(2, r$path$level, r$path$slope); s30 <- spot_curve(30, r$path$level, r$path$slope)
    par(mar = c(4, 5, 2, 1))
    plot(r$path$year, 100 * r$sim$ten_year_rate, type = "l", lwd = 3, col = "#1565c0",
         ylim = range(100 * c(s2, s30, r$sim$ten_year_rate)), xlab = "Year", ylab = "Rate (%)", main = "The storm")
    lines(r$path$year, 100 * s2, col = "#ef6c00", lwd = 2)
    lines(r$path$year, 100 * s30, col = "#6a1b9a", lwd = 2)
    legend("topleft", c("2-year", "10-year", "30-year"), col = c("#ef6c00", "#1565c0", "#6a1b9a"), lwd = 2, bty = "n", horiz = TRUE)
  })

  output$newspaper <- renderUI({
    req(input$go > 0)
    h <- storm_headlines(result()$sim)
    if (length(h) == 0) h <- "A quiet twenty years: the cheques went out and nobody noticed."
    div(style = "background:#fffdf5;border:1px solid #ccc;padding:10px;font-family:Georgia,serif;",
      h4("\U0001F4F0 The Yield Curve Gazette"),
      tags$ul(lapply(h, tags$li)))
  })

  output$report <- renderUI({
    req(input$go > 0)
    r <- result()
    sc <- storm_score(r$sim); g <- storm_grade(sc)
    survived <- all(storm_status(r$sim) != "Underwater")
    badge <- if (survived && r$storm != "calm") p(strong("\U0001F3C6 Storm Survivor: never underwater")) else NULL
    game_no <- if (r$storm == "random") p(sprintf("Game number %.0f. Share it to replay the same storm.", r$seed)) else NULL
    div(style = "background:#f4f6f6;border-radius:8px;padding:10px;",
      h4("Report card"),
      h2(sprintf("Grade %s", g)),
      h4(STORM_TITLES[[g]]),
      p(sprintf("Worst surplus was %.0f%% of your starting capital.", 100 * sc)),
      badge, game_no)
  })

  output$compare <- renderTable({
    req(input$go > 0)
    tab <- result()$compare
    data.frame(Strategy = tab$strategy, `Worst surplus` = money_m(tab$worst_surplus),
               `Surplus at year 20` = money_m(tab$final_surplus),
               `Worst as % of capital` = sprintf("%.0f%%", 100 * tab$score), Grade = tab$grade,
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
    par(mar = c(4, 5, 2, 1))
    barplot(lc$cashflow / 1e6, names.arg = lc$t, col = "#80cbc4", border = NA, space = 0,
            xlab = "Year", ylab = "Expected payment ($M)", main = "The promise, year by year")
    abline(v = d - 0.5, col = "#c62828", lwd = 3)
    legend("topright", sprintf("Macaulay duration %.2f years", d), col = "#c62828", lwd = 3, bty = "n")
  })
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
    HTML(sprintf("<p>Coupon bonds bought: <b>%d</b>, strips bought: <b>%d</b>. Total cost at 5%%: <b>%s</b>, the PV of the promise: <b>%s</b>.
                  Largest yearly gap: <b>%s</b>. %s</p>",
                 length(ded$coupon_face), length(ded$strip_face), money(dedication_cost(ded, 0.05)), money(PVL),
                 money(max(abs(ded$gap))),
                 if (any(ded$coupon_face < 0)) "<span style='color:#c62828'>Some faces are negative: the coupons overshoot those years, so you would have to sell bonds short.</span>"
                 else "Every year is matched exactly, so no rate move can touch the surplus."))
  })
  output$c2_plot <- renderPlot({
    tab <- c2()$tab
    par(mar = c(4, 5, 2, 1))
    m <- rbind(tab$coupons, tab$redemptions, tab$strips) / 1e6
    barplot(m, names.arg = tab$year, col = c("#80cbc4", "#00897b", "#ffb74d"), border = NA, space = 0,
            xlab = "Year", ylab = "$M", main = "Bond cash flows stacked against each year's payment")
    points(tab$year - 0.5, tab$liability / 1e6, pch = 19, cex = 0.7)
    legend("topright", c("Coupons", "Bonds maturing", "Strips", "Promise"), fill = c("#80cbc4", "#00897b", "#ffb74d", NA),
           border = NA, pch = c(NA, NA, NA, 19), bty = "n")
  })
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
    HTML(sprintf("<ol><li>PV matches: %s %s</li><li>Duration matches: %s (%.4f years)</li>
                  <li>Convexity of bonds above the promise: %s (%.2f vs %.2f)</li></ol><p><b>%s</b></p>",
                 tick(ch$pv_match), money(ch$pv_assets), tick(ch$duration_match), ch$duration_assets,
                 tick(ch$convexity_ok), ch$convexity_assets, ch$convexity_liabilities,
                 if (ch$immunized) "Redington immunized: small parallel shifts cannot create a loss."
                 else "Not immunized: duration alone is not enough, and this pair loses money when rates move either way."))
  })
  output$c3_plot <- renderPlot({
    pr <- c3()$pr; fu <- c3()$full
    rates <- seq(0.01, 0.10, by = 0.001)
    sp <- surplus_curve(pr$face, pr$maturity, L, tt, rates)
    sf <- surplus_curve(fu$face, fu$maturity, L, tt, rates)
    par(mar = c(4, 5, 2, 1))
    plot(100 * rates, sp$surplus / 1e6, type = "l", lwd = 3, col = "#6a1b9a", ylim = range(c(sp$surplus, sf$surplus, 0) / 1e6),
         xlab = "Flat interest rate (%)", ylab = "Surplus ($M)", main = "Surplus if rates jump today to a new flat level")
    lines(100 * rates, sf$surplus / 1e6, lwd = 3, col = "#00897b")
    abline(h = 0, col = "#c62828"); abline(v = 5, lty = 3)
    legend("top", c(sprintf("%s and %s year strips", input$c3_m1, input$c3_m2), "Full immunization"),
           col = c("#6a1b9a", "#00897b"), lwd = 3, bty = "n")
  })
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
    if (!is.null(s$player)) k <- rbind(k, `Your portfolio` = key_rate_durations(s$player$face, s$player$maturity))
    par(mar = c(4, 5, 2, 1))
    barplot(k, beside = TRUE, col = c("#424242", "#6a1b9a", "#00897b", "#ef6c00")[seq_len(nrow(k))], border = NA,
            xlab = "Key rate", ylab = "Key rate duration", legend.text = rownames(k), args.legend = list(bty = "n"))
  })
  c4_res <- reactive({
    sh <- random_shocks(1000, input$c4_sdl, input$c4_sds, input$c4_seed)
    s <- c4_strats()
    sapply(s, function(st) st$cash + mapply(function(lv, sl) shock_surplus(st$face, st$maturity, L, tt, lv, sl), sh$level, sh$slope))
  })
  output$c4_hist <- renderPlot({
    r <- c4_res()
    br <- pretty(range(r / 1e6), 40)
    par(mar = c(4, 5, 2, 1))
    cols <- c(redington = "#6a1b9a80", full = "#00897b80", player = "#ef6c0080")
    hist(r[, 1] / 1e6, breaks = br, col = cols[colnames(r)[1]], border = NA, main = "Surplus after the shock",
         xlab = "Surplus ($M)", ylim = c(0, 1000))
    for (k in 2:ncol(r)) hist(r[, k] / 1e6, breaks = br, col = cols[colnames(r)[k]], border = NA, add = TRUE)
    abline(v = 0, col = "#c62828", lwd = 2)
    legend("topright", c(redington = "Redington barbell", full = "Full immunization", player = "Your portfolio")[colnames(r)],
           fill = cols[colnames(r)], border = NA, bty = "n")
  })
  output$c4_table <- renderTable({
    r <- c4_res()
    lab <- c(redington = "Redington barbell", full = "Full immunization", player = "Your portfolio")
    data.frame(Strategy = lab[colnames(r)], `Average surplus` = money_m(colMeans(r)),
               `5th percentile` = money_m(apply(r, 2, quantile, 0.05)),
               `Chance surplus is negative` = sprintf("%.1f%%", 100 * colMeans(r < 0)), check.names = FALSE)
  })
}

shinyApp(ui, server)
