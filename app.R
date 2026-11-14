# Pittsburgh Penguins Ticketing & Fan Revenue Analytics HUB
# STAGE 5B: Stage 4B dashboards + historical attendance backtest + synthetic what-if
# Open Penguins-Ticketing-HUB.Rproj, then run: shiny::runApp()
# No Git initialization required.

required_packages <- c("shiny", "bslib", "dplyr", "ggplot2", "scales", "DT")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop("Missing Shiny packages: ", paste(missing_packages, collapse = ", "),
       ". Run source('scripts/07_install_shiny_packages.R')", call. = FALSE)
}

source("R/shiny_helpers.R")
source("R/shiny_data.R")
source("R/module_attendance.R")
source("R/module_revenue.R")
source("R/shiny_customer_data.R")
source("R/module_customers.R")
source("R/shiny_opportunity_helpers.R")
source("R/shiny_forecast_data.R")
source("R/module_forecast.R")

# Load validated files and precompute aggregates at startup; never per interaction.
hub_data <- load_stage4a_data()
customer_data <- load_stage4b_data(hub_data)
forecast_data <- load_stage5b_data(hub_data)

ui <- bslib::page_navbar(
  title = shiny::tags$div(
    class = "brand-lockup",
    shiny::tags$span(class = "brand-monogram", "P"),
    shiny::tags$span(class = "brand-name",
                     shiny::tags$strong("PENGUINS"),
                     shiny::tags$small("TICKETING & FAN REVENUE  /  ANALYTICS HUB"))
  ),
  id = "main_navigation",
  selected = "Attendance & Demand",
  fillable = FALSE,
  window_title = "Penguins | Ticketing & Fan Revenue Analytics HUB",
  theme = bslib::bs_theme(
    version = 5, preset = "bootstrap",
    bg = "#0A1017", fg = "#EDF2F5",
    primary = PENS_GOLD, secondary = "#A3B0BC"
  ),
  header = shiny::tagList(
    shiny::tags$head(
      shiny::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
      shiny::tags$link(rel = "stylesheet", type = "text/css", href = "styles.css"),
      shiny::tags$link(rel = "stylesheet", type = "text/css", href = "stage4b.css"),
      shiny::tags$link(rel = "stylesheet", type = "text/css", href = "stage5b.css")
    ),
    shiny::tags$section(
      class = "filters-shell",
      shiny::tags$div(
        class = "filters-title",
        shiny::tags$span(class = "filters-kicker", "GLOBAL VIEW"),
        shiny::tags$h2("Game filters"),
        shiny::tags$p(shiny::textOutput("selected_game_count", inline = TRUE))
      ),
      shiny::tags$div(
        class = "filters-controls",
        shiny::tags$div(class = "filter-control",
                         shiny::selectInput("season_filter", "Season",
                                            choices = c("All three seasons" = "All",
                                                        "2023–24" = "2023-24",
                                                        "2024–25" = "2024-25",
                                                        "2025–26" = "2025-26"),
                                            selected = "All", width = "100%")),
        shiny::tags$div(class = "filter-control",
                         shiny::selectInput("opponent_filter", "Opponent",
                                            choices = c("All opponents" = "All",
                                                        stats::setNames(
                                                          sort(unique(hub_data$real$opponent)),
                                                          sort(unique(hub_data$real$opponent)))),
                                            selected = "All", width = "100%")),
        shiny::tags$div(class = "filter-control",
                         shiny::selectInput("day_filter", "Game day",
                                            choices = c("All days" = "All", "Weekdays" = "Weekday",
                                                        "Weekends" = "Weekend"),
                                            selected = "All", width = "100%")),
        shiny::tags$div(class = "filter-reset",
                         shiny::actionButton("reset_filters", "Reset filters", class = "reset-btn"))
      )
    )
  ),
  bslib::nav_panel("Attendance & Demand", attendance_ui("attendance")),
  bslib::nav_panel("Ticket Sales & Revenue", revenue_ui("revenue")),
  bslib::nav_panel("Customer & Membership", customers_ui("customers")),
  bslib::nav_panel("Forecasting & Opportunities", forecast_ui("forecast")),
  bslib::nav_panel(
    "Methodology",
    shiny::tags$div(
      class = "dashboard-page methodology-page",
      shiny::tags$section(class = "page-intro",
                          shiny::tags$div(
                            shiny::tags$div(class = "eyebrow", "DATA GOVERNANCE  /  05"),
                            shiny::tags$h1("How to read this dashboard"),
                            shiny::tags$p("A clear boundary between publicly reported NHL game data and illustrative commercial simulations."))),
      shiny::tags$div(
        class = "chart-grid chart-grid-main",
        section_panel("Actual NHL attendance",
                      "Real historical data",
                      shiny::tags$p("Game date, opponent, final result, venue and reported attendance are from official NHL reports for the 2023–24, 2024–25 and 2025–26 seasons."),
                      shiny::tags$p("The app uses 122 regular-season games played at PPG Paints Arena. One designated Pittsburgh home game in Stockholm is retained in the Stage 2 master data but excluded from this venue-specific dashboard.")),
        section_panel("Synthetic ticketing operations",
                      "Not official Pittsburgh Penguins business data",
                      shiny::tags$p("Seat inventory, customers, ticket orders, paid prices, ticket volume, revenue, channels and memberships were generated by a reproducible R simulation. None are records from the Penguins' ticketing or CRM systems."),
                      shiny::tags$p("Membership purchase amounts are allocated once across eligible games. The dashboard sums earned allocations, not both the upfront order and the same game-level tickets.")),
        section_panel("Synthetic customer & membership analytics",
                      "Full-season cohorts versus filtered game activity",
                      shiny::tags$p("The customer tab uses anonymous simulated accounts, membership contracts, order headers and allocated game rights. No personally identifying customer data is included."),
                      shiny::tags$p("Opponent and weekday filters affect selected-game engagement and revenue only. Renewal and purchaser retention rates use full-season cohorts, and change only when the season filter changes."),
                      shiny::tags$p("First-observed buyers have no earlier synthetic purchase within 2023–26; they are not necessarily new real-world fans. The 2023–24 baseline has no observable prior season, so renewal and retention are unavailable.")),
        section_panel("Historical model backtest",
                      "Model predictions are not future NHL forecasts",
                      shiny::tags$p("The 2023–24 games trained the candidate models; 2024–25 served as validation. The best ridge penalty and final model selection were chosen before testing on the 40 games played at PPG Paints Arena in 2025–26."),
                      shiny::tags$p("The historical-mean model was preselected under the minimum-validation-improvement rule, despite ridge having lower test error. Model MAE and RMSE are computed from real NHL attendance observations and retrospective estimates.")),
        section_panel("Synthetic opportunity calculator",
                      "User-controlled financial assumptions, not predictions",
                      shiny::tags$p("Game filters define which synthetic inventory and sales are included. Each game starts with simulated unsold seats = sellable inventory minus simulated paid tickets. Incremental tickets = floor(unsold seats × scenario conversion rate), capped by remaining hypothetical capacity."),
                      shiny::tags$p("Incremental ticket revenue equals additional tickets times user-assumed net price. Assumed marketing spend is additional tickets times assumed acquisition cost. Their difference is not profit: fees, cannibalization, other operating expenses and demand responses are not modeled."))
      ),
      section_panel("KPI definitions",
                    "Game-level filters and season-level cohort definitions",
                    shiny::tags$div(class = "definitions-grid",
                      shiny::tags$div(shiny::tags$strong("Nominal utilization"),
                        shiny::tags$p("Sum of reported attendance ÷ sum of published nominal PPG Paints Arena capacities. May exceed 100% because published attendance can differ from nominal seating capacity.")),
                      shiny::tags$div(shiny::tags$strong("Simulated sell-through"),
                        shiny::tags$p("Sum of simulated paid ticket entitlements ÷ sum of hypothetical sellable inventory across selected games.")),
                      shiny::tags$div(shiny::tags$strong("Simulated net revenue"),
                        shiny::tags$p("Sum of synthetic ticket-line net revenue, including one allocated entitlement per membership ticket per eligible game.")),
                      shiny::tags$div(shiny::tags$strong("Average paid ticket price"),
                        shiny::tags$p("Simulated net ticket revenue ÷ simulated paid tickets, using totals across selected games.")),
                      shiny::tags$div(shiny::tags$strong("Synthetic member renewal rate"),
                        shiny::tags$p("Eligible prior-season members appearing in the current season ÷ all prior-season members. This is a full-season measure.")),
                      shiny::tags$div(shiny::tags$strong("Synthetic purchaser retention"),
                        shiny::tags$p("Prior-season purchasers who return in the following season ÷ all prior-season purchasers. Membership orders count once.")),
                      shiny::tags$div(shiny::tags$strong("Customer game engagement"),
                        shiny::tags$p("Unique synthetic accounts with a ticket entitlement for each selected game. Game rights do not prove turnstile attendance.")),
                      shiny::tags$div(shiny::tags$strong("Backtest MAE / RMSE"),
                        shiny::tags$p("Out-of-time 2025–26 attendance prediction errors in fans per game. The model was selected using 2024–25 validation, never using 2025–26 outcomes.")),
                      shiny::tags$div(shiny::tags$strong("What-if extra ticket revenue"),
                        shiny::tags$p("Synthetic unsold seats × user-assumed conversion, rounded down per game, × assumed net price. This is a scenario, not a demand or ticket revenue forecast."))
                    )),
      shiny::tags$div(class = "note-banner",
                       "Simulation caution: synthetic sales were partially calibrated to actual attendance patterns. Do not treat them as real observed revenue or use them as an independent predictor of historical NHL attendance.")
    )
  ),
  footer = shiny::tags$footer(
    class = "site-footer",
    shiny::tags$span("PENGUINS TICKETING & FAN REVENUE ANALYTICS HUB"),
    shiny::tags$span("Educational portfolio · No affiliation with the Pittsburgh Penguins or NHL · Financial/CRM data: SYNTHETIC")
  )
)

server <- function(input, output, session) {
  filtered_real <- shiny::reactive({
    filter_real_games(
      hub_data$real,
      season = input$season_filter,
      opponent = input$opponent_filter,
      day_type = input$day_filter
    )
  })
  selected_ids <- shiny::reactive(filtered_real()$game_id)
  filtered_business <- shiny::reactive({
    df <- hub_data$business[hub_data$business$game_id %in% selected_ids(), , drop = FALSE]
    df[order(df$game_date, df$game_id), , drop = FALSE]
  })
  filtered_category <- shiny::reactive(
    hub_data$category[hub_data$category$game_id %in% selected_ids(), , drop = FALSE]
  )
  filtered_channel <- shiny::reactive(
    hub_data$channel[hub_data$channel$game_id %in% selected_ids(), , drop = FALSE]
  )

  output$selected_game_count <- shiny::renderText({
    paste0(nrow(filtered_real()), " PPG Paints Arena home games selected")
  })

  shiny::observeEvent(input$reset_filters, {
    shiny::updateSelectInput(session, "season_filter", selected = "All")
    shiny::updateSelectInput(session, "opponent_filter", selected = "All")
    shiny::updateSelectInput(session, "day_filter", selected = "All")
  })

  attendance_server("attendance", games = filtered_real)
  revenue_server("revenue", business = filtered_business,
                 categories = filtered_category, channels = filtered_channel)
  customers_server("customers", customer_data = customer_data,
                   selected_ids = selected_ids,
                   season_filter = shiny::reactive(input$season_filter))
  forecast_server("forecast", forecast_data = forecast_data,
                  business = filtered_business, selected_ids = selected_ids)
}

shiny::shinyApp(ui, server)
