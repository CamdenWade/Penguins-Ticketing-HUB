# STAGE 5B — Historical holdout evaluation (REAL outcome, MODEL estimates)
# and an entirely independent SYNTHETIC ticket-inventory scenario.
# Neither display is a live future-game forecast or an official revenue projection.

forecast_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$div(
    class = "dashboard-page forecast-page",
    shiny::tags$section(
      class = "page-intro",
      shiny::tags$div(
        shiny::tags$div(class = "eyebrow", "DECISION INTELLIGENCE  /  04"),
        shiny::tags$h1("Attendance Models & Revenue Opportunities"),
        shiny::tags$p("Review an out-of-time historical attendance backtest, then explore hypothetical ticket-sales opportunities within simulated inventory limits.")
      ),
      shiny::tags$span(class = "data-pill synthetic-pill", "BACKTEST + WHAT-IF")
    ),
    shiny::tags$div(
      class = "note-banner forecast-note",
      shiny::tags$strong("Two separate analyses"),
      "Historical attendance is real NHL data; model predictions are retrospective estimates for 2025–26 games. All ticket inventory, prices, extra sales, expenses and revenue below are synthetic assumptions. No predictions for upcoming games are shown."
    ),
    shiny::tags$div(class = "subsection-heading",
      shiny::tags$div(class = "eyebrow", "MODEL EVALUATION  /  REAL NHL ATTENDANCE"),
      shiny::tags$h2("Historical out-of-time backtest"),
      shiny::tags$p("The final model was chosen using 2024–25 validation data, then evaluated on 40 held-out 2025–26 PPG Paints Arena games. Model scores in the cards are fixed for all 40 games; the chart and ledger respond to the global game filters.")
    ),
    shiny::uiOutput(ns("model_metrics")),
    shiny::tags$div(class = "chart-grid chart-grid-main",
      section_panel(
        "Actual versus model-estimated attendance",
        "Only 2025–26 held-out games appear here · Global filters apply",
        shiny::tags$div(class = "forecast-filter-note", shiny::textOutput(ns("backtest_selection"))),
        shiny::plotOutput(ns("backtest_plot"), height = "385px")
      ),
      section_panel(
        "What the backtest tells us",
        "Selection discipline and limitations",
        shiny::uiOutput(ns("model_explanation")),
        shiny::tags$div(class = "forecast-evaluation-caveat",
          "MAE and RMSE describe errors on historical games. These estimates are not live demand forecasts and should not be used as predictions of actual paid ticket sales."
        )
      )
    ),
    section_panel(
      "Held-out game predictions",
      "Observed attendance: REAL NHL · Model estimates: BACKTEST · 2025–26 games matching global filters",
      shiny::tags$div(class = "table-actions",
        shiny::downloadButton(ns("download_backtest"), "Export historical backtest CSV", class = "btn-export")
      ),
      DT::DTOutput(ns("backtest_table")),
      class = "table-panel"
    ),
    shiny::tags$div(class = "subsection-heading subsection-spaced",
      shiny::tags$div(class = "eyebrow", "HYPOTHETICAL COMMERCIAL SCENARIO  /  SYNTHETIC"),
      shiny::tags$h2("Incremental ticket revenue opportunity"),
      shiny::tags$p("Choose how many currently unsold synthetic seats could convert into extra paid tickets, an assumed net price per incremental seat and a hypothetical customer-acquisition cost. All calculations respond to the shared game filters.")
    ),
    shiny::tags$div(class = "note-banner synthetic-note",
      shiny::tags$strong("Assumptions, not forecasts"),
      "Incremental sales are limited to unsold simulated inventory on each game. The tool does not estimate conversion probability, price elasticity, demand causality, or actual Penguins revenue. Revenue less the specified marketing cost is NOT profit."
    ),
    shiny::tags$section(class = "scenario-controls",
      shiny::tags$div(class = "scenario-control",
        shiny::sliderInput(ns("capture_pct"), "Convert unsold inventory", min = 0, max = 100,
                           value = 15, step = 5, post = "%")
      ),
      shiny::tags$div(class = "scenario-control",
        shiny::sliderInput(ns("incremental_price"), "Net price per additional ticket", min = 20,
                           max = 300, value = 90, step = 5, pre = "$")
      ),
      shiny::tags$div(class = "scenario-control",
        shiny::sliderInput(ns("acquisition_cost"), "Assumed marketing cost per extra ticket",
                           min = 0, max = 100, value = 10, step = 5, pre = "$")
      )
    ),
    shiny::uiOutput(ns("scenario_metrics")),
    shiny::tags$div(class = "chart-grid chart-grid-main",
      section_panel(
        "Illustrative incremental revenue by game",
        "Top 12 currently selected games by added gross ticket revenue · All values synthetic",
        shiny::plotOutput(ns("scenario_plot"), height = "390px")
      ),
      section_panel(
        "Scenario interpretation",
        "Business opportunity illustration, not a revenue forecast",
        shiny::uiOutput(ns("scenario_takeaway"))
      )
    ),
    section_panel(
      "Synthetic game-by-game opportunity ledger",
      "Incremental tickets are capped at each game's unsold hypothetical inventory",
      shiny::tags$div(class = "table-actions",
        shiny::downloadButton(ns("download_scenario"), "Export synthetic scenario CSV", class = "btn-export")
      ),
      DT::DTOutput(ns("scenario_table")),
      class = "table-panel"
    )
  )
}

forecast_server <- function(id, forecast_data, business, selected_ids) {
  shiny::moduleServer(id, function(input, output, session) {
    selected_model <- forecast_data$selected_model
    selected_label <- if (identical(selected_model, "historical_mean")) {
      "Historical mean"
    } else {
      "Ridge regression"
    }
    challenger_name <- if (identical(selected_model, "historical_mean")) {
      "ridge"
    } else {
      "historical_mean"
    }
    challenger_label <- if (identical(challenger_name, "ridge")) "Ridge" else "Historical mean"
    saved_metrics <- forecast_data$metrics
    selected_metrics <- saved_metrics[saved_metrics$model == selected_model, , drop = FALSE]
    challenger_metrics <- saved_metrics[saved_metrics$model == challenger_name, , drop = FALSE]

    selected_backtest <- shiny::reactive({
      p <- forecast_data$predictions
      p[p$game_id %in% selected_ids(), , drop = FALSE]
    })

    output$model_metrics <- shiny::renderUI({
      shiny::tags$div(class = "metric-grid",
        metric_card("Preselected model", selected_label,
                    "Chosen by 2024–25 validation, not by 2025–26 test results", "real"),
        metric_card("Selected model test MAE", format_count(selected_metrics$mae),
                    "Fans per game · 40-game historical test", "real"),
        metric_card("Selected model test RMSE", format_count(selected_metrics$rmse),
                    "Fans per game · 40-game historical test", "real"),
        metric_card("Challenger test MAE", format_count(challenger_metrics$mae),
                    paste(challenger_label, "· comparison only; not retrospectively promoted"), "real")
      )
    })

    output$backtest_selection <- shiny::renderText({
      paste0(nrow(selected_backtest()), " of 40 held-out games match the current global filters")
    })

    output$model_explanation <- shiny::renderUI({
      validation <- forecast_data$validation_scores
      baseline <- validation[validation$model == "historical_mean", , drop = FALSE]
      ridge <- validation[validation$model == "ridge", , drop = FALSE]
      best_ridge <- ridge[order(ridge$mae, ridge$rmse, ridge$lambda)[1L], , drop = FALSE]
      gained <- baseline$mae - best_ridge$mae
      shiny::tags$div(class = "forecast-story",
        shiny::tags$p(shiny::tags$strong("Selection before testing. "),
          sprintf("On the 2024–25 validation season, the best ridge fit improved MAE by %.1f attendees per game relative to the historical mean. The precommitted requirement was at least 50; therefore the historical mean remained selected.", gained)),
        shiny::tags$p(shiny::tags$strong("Test-season comparison. "),
          sprintf("On the untouched 2025–26 season, the selected model MAE was %s and the ridge challenger MAE was %s attendees per game. Ridge's lower test error does not justify changing the selection after seeing the holdout.",
                  format_count(saved_metrics$mae[saved_metrics$model == "historical_mean"]),
                  format_count(saved_metrics$mae[saved_metrics$model == "ridge"]))),
        shiny::tags$p(shiny::tags$strong("Business interpretation. "),
          "Attendance levels can shift between seasons; simple historical averages are informative but do not capture every demand driver. A future live forecasting system would need more seasons and genuinely available pregame predictors.")
      )
    })

    output$backtest_plot <- shiny::renderPlot({
      df <- selected_backtest()
      if (!nrow(df)) return(empty_plot("No 2025–26 held-out games match these filters"))
      challenger <- df[[paste0("predicted_", challenger_name)]]
      df$challenger_attendance <- challenger
      ggplot2::ggplot(df, ggplot2::aes(x = .data$game_date)) +
        ggplot2::geom_line(ggplot2::aes(y = .data$predicted_selected,
                                       colour = "Selected model"), linewidth = 0.9) +
        ggplot2::geom_line(ggplot2::aes(y = .data$challenger_attendance,
                                       colour = "Challenger"), linewidth = 0.8, linetype = "22") +
        ggplot2::geom_point(ggplot2::aes(y = .data$actual_attendance,
                                        colour = "Actual NHL attendance"), size = 2.6) +
        ggplot2::scale_colour_manual(
          values = c("Actual NHL attendance" = "#E8F1F7",
                     "Selected model" = PENS_GOLD, "Challenger" = PENS_SKY),
          breaks = c("Actual NHL attendance", "Selected model", "Challenger")
        ) +
        ggplot2::scale_x_date(date_labels = "%b '%y", date_breaks = "1 month") +
        ggplot2::scale_y_continuous(labels = scales::comma,
                                     breaks = scales::breaks_pretty(n = 5)) +
        ggplot2::labs(x = NULL, y = "Reported attendance / model estimate", colour = NULL) +
        penguins_plot_theme() +
        ggplot2::theme(legend.position = "bottom",
                       legend.text = ggplot2::element_text(colour = "#E8EEF3", size = 10))
    }, res = 110)

    output$backtest_table <- DT::renderDT({
      p <- selected_backtest()
      display <- data.frame(
        Date = as.Date(p$game_date),
        Opponent = p$opponent,
        `Actual (real NHL)` = p$actual_attendance,
        `Historical mean (model)` = p$predicted_historical_mean,
        `Ridge (model)` = p$predicted_ridge,
        `Selected error (abs)` = p$absolute_error,
        check.names = FALSE
      )
      dt <- DT::datatable(display, rownames = FALSE,
                          options = list(pageLength = 8, scrollX = TRUE,
                                         order = list(list(0, "asc")), dom = "ftip"),
                          class = "compact stripe hover")
      DT::formatRound(dt, c("Actual (real NHL)", "Historical mean (model)",
                            "Ridge (model)", "Selected error (abs)"), digits = 0)
    }, server = FALSE)

    output$download_backtest <- shiny::downloadHandler(
      filename = function() paste0("penguins_REAL_NHL_historical_BACKTEST_", Sys.Date(), ".csv"),
      content = function(file) {
        out <- selected_backtest()
        out$prediction_origin <- "MODEL_ESTIMATE_HISTORICAL_BACKTEST_NOT_FUTURE"
        utils::write.csv(out, file, row.names = FALSE, na = "")
      }
    )

    scenario_games <- shiny::reactive({
      calculate_ticket_opportunity(
        business(),
        capture_pct = input$capture_pct,
        incremental_price_usd = input$incremental_price,
        acquisition_cost_usd = input$acquisition_cost
      )
    })
    scenario_totals <- shiny::reactive(summarize_ticket_opportunity(scenario_games()))

    output$scenario_metrics <- shiny::renderUI({
      x <- scenario_totals()
      shiny::tags$div(class = "metric-grid",
        metric_card("Additional simulated tickets", format_count(x$extra),
                    paste(format_count(x$unsold), "currently unsold synthetic seats"), "synthetic"),
        metric_card("Added gross ticket revenue", format_money(x$gross_revenue_usd),
                    "Extra paid tickets × assumed net ticket price", "synthetic"),
        metric_card("Revenue less assumed campaign spend",
                    format_money(x$contribution_after_assumed_marketing_usd),
                    "Illustrative contribution before all other expenses · not profit", "synthetic"),
        metric_card("Scenario sell-through", format_percent(x$scenario_sellthrough),
                    paste0("Baseline: ", format_percent(x$current_sellthrough),
                           " · capped at synthetic capacity"), "synthetic")
      )
    })

    output$scenario_takeaway <- shiny::renderUI({
      x <- scenario_totals()
      if (!x$games) return(shiny::tags$p("No games match the filters. Expand the selection to evaluate a synthetic scenario."))
      shiny::tags$div(class = "forecast-story",
        shiny::tags$p(paste0(
          "For ", format_count(x$games), " selected game(s), the hypothetical baseline has ",
          format_count(x$unsold), " unsold seats. The chosen conversion rate would add ",
          format_count(x$extra), " paid tickets and ", format_money(x$gross_revenue_usd),
          " in incremental gross ticket revenue."
        )),
        shiny::tags$p(paste0(
          "After ", format_money(x$marketing_spend_usd),
          " of user-assumed acquisition spend, the illustrative remainder is ",
          format_money(x$contribution_after_assumed_marketing_usd),
          ". Other costs, fees, displacement and demand responses are not modeled."
        )),
        shiny::tags$p(shiny::tags$strong("Decision use: "),
          "This demonstrates how a ticketing team might size a promotion against remaining inventory, not whether fans would actually purchase at the chosen price.")
      )
    })

    output$scenario_plot <- shiny::renderPlot({
      data <- scenario_games()
      data <- data[data$scenario_added_revenue_cents > 0, , drop = FALSE]
      if (!nrow(data)) return(empty_plot("No incremental sales under these assumptions"))
      data <- data[order(-data$scenario_added_revenue_cents, data$game_date), , drop = FALSE]
      data <- utils::head(data, 12L)
      data$game_label <- paste(format(data$game_date, "%b %d '%y"),
                               "vs", data$opponent)
      data$game_label <- factor(data$game_label, levels = rev(data$game_label))
      ggplot2::ggplot(data, ggplot2::aes(x = .data$game_label,
                                        y = .data$scenario_added_revenue_cents / 100)) +
        ggplot2::geom_col(fill = PENS_GOLD, width = 0.65) +
        ggplot2::coord_flip() +
        ggplot2::scale_y_continuous(labels = scales::label_dollar(),
                                    expand = ggplot2::expansion(mult = c(0, 0.09))) +
        ggplot2::labs(x = NULL, y = "Additional synthetic ticket revenue (USD)") +
        penguins_plot_theme() +
        ggplot2::theme(axis.text.y = ggplot2::element_text(size = 10))
    }, res = 110)

    output$scenario_table <- DT::renderDT({
      x <- scenario_games()
      display <- data.frame(
        Date = x$game_date,
        Season = x$season,
        Opponent = x$opponent,
        `Unsold (sim)` = x$sim_unsold_seats,
        `Added tickets (what-if)` = x$scenario_extra_tickets,
        `Added revenue (sim USD)` = x$scenario_added_revenue_cents / 100,
        `Campaign spend (sim USD)` = x$scenario_marketing_spend_cents / 100,
        `Scenario sell-through` = x$scenario_sellthrough,
        check.names = FALSE
      )
      dt <- DT::datatable(display, rownames = FALSE,
                          options = list(pageLength = 8, scrollX = TRUE,
                                         order = list(list(0, "desc")), dom = "ftip"),
                          class = "compact stripe hover")
      dt <- DT::formatRound(dt, c("Unsold (sim)", "Added tickets (what-if)"), digits = 0)
      dt <- DT::formatCurrency(dt, c("Added revenue (sim USD)", "Campaign spend (sim USD)"),
                               currency = "$", digits = 2)
      DT::formatPercentage(dt, "Scenario sell-through", digits = 1)
    }, server = FALSE)

    output$download_scenario <- shiny::downloadHandler(
      filename = function() paste0("penguins_SYNTHETIC_WHAT_IF_", Sys.Date(), ".csv"),
      content = function(file) utils::write.csv(scenario_games(), file, row.names = FALSE, na = "")
    )
  })
}
