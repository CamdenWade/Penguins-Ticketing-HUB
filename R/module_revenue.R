# STAGE 4A: SYNTHETIC ticket sales, inventory and ticket revenue.
# All financial values are simulated and are NOT official Penguins data.

revenue_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$div(
    class = "dashboard-page",
    shiny::tags$section(
      class = "page-intro",
      shiny::tags$div(
        shiny::tags$div(class = "eyebrow", "COMMERCIAL PERFORMANCE  /  02"),
        shiny::tags$h1("Ticket Sales & Revenue"),
        shiny::tags$p("Explore hypothetical ticket inventory, earned ticket revenue, customer channels, and price-versus-volume patterns.")
      ),
      shiny::tags$span(class = "data-pill synthetic-pill", "SYNTHETIC SCENARIO")
    ),
    shiny::tags$div(
      class = "note-banner synthetic-note",
      shiny::tags$strong("Simulated data only"),
      "All purchases, seat inventory, ticket prices, sales channels and revenue are synthetic. These are illustrative business scenarios, not actual or estimated Penguins financial results. Membership revenue is allocated across covered games once."
    ),
    shiny::uiOutput(ns("metrics")),
    shiny::tags$div(
      class = "chart-grid chart-grid-main",
      section_panel(
        "Illustrative ticket revenue by game",
        "Synthetic game-level earned revenue · Includes allocated season memberships",
        shiny::plotOutput(ns("revenue_trend"), height = "405px")
      ),
      section_panel(
        "Sales channel mix",
        "Ticket volume by synthetic purchase channel",
        shiny::plotOutput(ns("channels"), height = "335px")
      )
    ),
    shiny::tags$div(
      class = "chart-grid chart-grid-main",
      section_panel(
        "Synthetic revenue by seating category",
        "Membership entitlements and individual transactions included once",
        shiny::plotOutput(ns("seats"), height = "345px")
      ),
      section_panel(
        "Business interpretation",
        "What a ticketing team could investigate",
        shiny::tags$div(
          class = "insight-list",
          shiny::tags$div("01", shiny::tags$span("Which hypothetical inventory categories contribute the most earned revenue?")),
          shiny::tags$div("02", shiny::tags$span("Are lower-volume games compensated by higher average prices?")),
          shiny::tags$div("03", shiny::tags$span("How does membership allocation change the game-level sales mix?"))
        ),
        shiny::tags$div(class = "live-takeaway", shiny::uiOutput(ns("takeaway"))),
        shiny::tags$p(class = "insight-caveat",
                      "Synthetic paid sales were partially calibrated to actual attendance; they are not independent evidence of a real revenue trend.")
      )
    ),
    section_panel(
      "Simulated game business ledger",
      "Sortable and searchable; download includes source/provenance fields.",
      shiny::tags$div(class = "table-actions", shiny::downloadButton(ns("download"), "Export synthetic game CSV", class = "btn-export")),
      DT::DTOutput(ns("business_table")),
      class = "table-panel"
    )
  )
}

revenue_server <- function(id, business, categories, channels) {
  shiny::moduleServer(id, function(input, output, session) {
    output$metrics <- shiny::renderUI({
      df <- business()
      n <- nrow(df)
      revenue <- if (n) sum(as.double(df$sim_ticket_revenue_cents)) / 100 else NA_real_
      tickets <- if (n) sum(as.double(df$sim_paid_tickets)) else NA_real_
      sellthrough <- if (n) safe_ratio(tickets, sum(as.double(df$sellable_seats))) else NA_real_
      unit_price <- safe_ratio(revenue, tickets)
      shiny::tags$div(
        class = "metric-grid",
        metric_card("Simulated ticket revenue", format_money(revenue), "Net game-level earned revenue · hypothetical", "synthetic"),
        metric_card("Simulated paid tickets", format_count(tickets), "Includes allocated season member entitlements", "synthetic"),
        metric_card("Simulated sell-through", format_percent(sellthrough), "Paid tickets ÷ synthetic sellable inventory", "synthetic"),
        metric_card("Average paid ticket price", format_price(unit_price), "Revenue ÷ paid tickets · simulated", "synthetic")
      )
    })

    output$takeaway <- shiny::renderUI({
      df <- business()
      if (!nrow(df)) return(shiny::tags$p("Choose a broader filter to view synthetic sales insights."))
      tickets <- sum(as.double(df$sim_paid_tickets))
      revenue <- sum(as.double(df$sim_ticket_revenue_cents)) / 100
      sellthrough <- safe_ratio(tickets, sum(as.double(df$sellable_seats)))
      shiny::tags$p(paste0(
        "In this hypothetical scenario, ", nrow(df), " selected games produced ",
        format_money(revenue), " in earned ticket revenue at ",
        format_percent(sellthrough), " paid ticket sell-through."
      ))
    })

    output$revenue_trend <- shiny::renderPlot({
      df <- business()
      if (!nrow(df)) return(empty_plot())
      p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$game_date,
                                           y = as.double(.data$sim_ticket_revenue_cents) / 100)) +
        ggplot2::geom_col(fill = PENS_GOLD, width = 4) +
        ggplot2::scale_y_continuous(
          labels = scales::label_dollar(scale = 1e-6, suffix = "M", accuracy = 0.1),
          expand = ggplot2::expansion(mult = c(0, 0.12))
        ) +
        ggplot2::labs(x = NULL, y = "Simulated revenue (USD)") +
        penguins_plot_theme()
      if (dplyr::n_distinct(df$season) > 1L) {
        p <- p + ggplot2::facet_wrap(~ season, scales = "free_x", ncol = 1) +
          ggplot2::scale_x_date(date_labels = "%b", date_breaks = "2 months")
      } else {
        p <- p + ggplot2::scale_x_date(date_labels = "%b '%y", date_breaks = "4 months")
      }
      p
    }, res = 110)

    output$channels <- shiny::renderPlot({
      df <- channels()
      if (!nrow(df)) return(empty_plot())
      mix <- df |>
        dplyr::group_by(.data$order_channel) |>
        dplyr::summarise(tickets = sum(.data$sim_paid_tickets), .groups = "drop")
      mix$channel_label <- c(SEASON_MEMBERSHIP = "Memberships", SINGLE_GAME = "Single game", GROUP = "Groups")[mix$order_channel]
      mix$channel_label <- factor(mix$channel_label,
                                  levels = c("Memberships", "Single game", "Groups"))
      ggplot2::ggplot(mix, ggplot2::aes(x = .data$channel_label, y = .data$tickets)) +
        ggplot2::geom_col(fill = PENS_SKY, width = 0.58) +
        ggplot2::scale_y_continuous(labels = scales::comma,
                                    expand = ggplot2::expansion(mult = c(0, 0.15))) +
        ggplot2::labs(x = NULL, y = "Synthetic paid tickets") +
        penguins_plot_theme()
    }, res = 110)

    output$seats <- shiny::renderPlot({
      df <- categories()
      if (!nrow(df)) return(empty_plot())
      totals <- df |>
        dplyr::group_by(.data$seat_category) |>
        dplyr::summarise(revenue_usd = sum(.data$sim_revenue_cents) / 100,
                         .groups = "drop") |>
        dplyr::arrange(dplyr::desc(.data$revenue_usd))
      totals$seat_category <- factor(totals$seat_category,
                                     levels = rev(totals$seat_category))
      ggplot2::ggplot(totals, ggplot2::aes(x = .data$seat_category, y = .data$revenue_usd)) +
        ggplot2::geom_col(fill = PENS_GOLD_SOFT, width = 0.65) +
        ggplot2::coord_flip() +
        ggplot2::scale_y_continuous(
          labels = scales::label_dollar(scale = 1e-6, suffix = "M", accuracy = 1),
          expand = ggplot2::expansion(mult = c(0, 0.14))
        ) +
        ggplot2::labs(x = NULL, y = "Simulated net revenue (USD)") +
        penguins_plot_theme()
    }, res = 110)

    output$business_table <- DT::renderDT({
      df <- business()
      visible <- data.frame(
        Date = as.Date(df$game_date),
        Season = df$season,
        Opponent = df$opponent,
        `Paid tickets (sim)` = as.double(df$sim_paid_tickets),
        `Net revenue (sim)` = as.double(df$sim_ticket_revenue_cents) / 100,
        `Sell-through (sim)` = as.double(df$sim_sellthrough),
        `Avg paid price (sim)` = as.double(df$sim_revenue_per_paid_ticket),
        check.names = FALSE
      )
      table <- DT::datatable(
        visible, rownames = FALSE,
        options = list(pageLength = 8, lengthMenu = c(8, 15, 30),
                       order = list(list(0, "desc")), scrollX = TRUE,
                       autoWidth = TRUE, dom = "ftip"),
        class = "compact stripe hover"
      )
      table <- DT::formatRound(table, "Paid tickets (sim)", digits = 0)
      table <- DT::formatCurrency(table, c("Net revenue (sim)", "Avg paid price (sim)"),
                                  currency = "$", digits = 2)
      DT::formatPercentage(table, "Sell-through (sim)", digits = 1)
    }, server = FALSE)

    output$download <- shiny::downloadHandler(
      filename = function() paste0("penguins_SYNTHETIC_ticketing_", Sys.Date(), ".csv"),
      content = function(file) {
        df <- business()
        export <- df[, c("game_id", "season", "game_date", "opponent",
                         "reported_attendance", "sim_paid_tickets",
                         "sim_ticket_revenue_cents", "sellable_seats", "capacity_seats",
                         "sim_sellthrough", "sim_revenue_per_paid_ticket",
                         "real_attendance_origin", "financial_data_origin"), drop = FALSE]
        utils::write.csv(export, file, row.names = FALSE, na = "")
      }
    )
  })
}
