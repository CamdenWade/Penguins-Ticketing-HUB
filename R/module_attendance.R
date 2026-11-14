# STAGE 4A: REAL NHL reported attendance module — PPG Paints Arena only.

attendance_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$div(
    class = "dashboard-page",
    shiny::tags$section(
      class = "page-intro",
      shiny::tags$div(
        shiny::tags$div(class = "eyebrow", "ATTENDANCE INTELLIGENCE  /  01"),
        shiny::tags$h1("Game Demand & Attendance"),
        shiny::tags$p("Track published Penguins home-game attendance, game-to-game trends, and opponent and schedule patterns.")
      ),
      shiny::tags$span(class = "data-pill real-pill", "REAL NHL DATA")
    ),
    shiny::tags$div(
      class = "note-banner",
      shiny::tags$strong("Measurement note"),
      "Reported attendance is not paid tickets sold. Nominal utilization uses 18,187 reference seats and may exceed 100%. The Stockholm designated home game is excluded."
    ),
    shiny::uiOutput(ns("metrics")),
    shiny::tags$div(
      class = "chart-grid chart-grid-main",
      section_panel(
        "Reported attendance over time",
        "Each point is a real PPG Paints Arena home game · Dashed line = published nominal capacity",
        shiny::plotOutput(ns("trend"), height = "405px")
      ),
      section_panel(
        "Weekday pattern",
        "Average reported attendance, with game counts shown inside bars",
        shiny::plotOutput(ns("weekday"), height = "335px")
      )
    ),
    shiny::tags$div(
      class = "chart-grid chart-grid-main",
      section_panel(
        "Opponents with strongest draw",
        "Top 10 opponents by average attendance in the current filter",
        shiny::plotOutput(ns("opponents"), height = "345px")
      ),
      section_panel(
        "What this view can answer",
        "Decision support for ticketing and game operations",
        shiny::tags$div(
          class = "insight-list",
          shiny::tags$div("01", shiny::tags$span("Which opponents regularly attract stronger home crowds?")),
          shiny::tags$div("02", shiny::tags$span("Does attendance differ between weekday and weekend games?")),
          shiny::tags$div("03", shiny::tags$span("Where might attendance patterns justify further promotional analysis?"))
        ),
        shiny::tags$div(class = "live-takeaway", shiny::uiOutput(ns("takeaway"))),
        shiny::tags$p(class = "insight-caveat",
                      "These are descriptive comparisons; they do not establish causal effects or ticket demand forecasts.")
      )
    ),
    section_panel(
      "Game-level attendance ledger",
      "Sortable and searchable NHL data; export follows the global filters.",
      shiny::tags$div(class = "table-actions", shiny::downloadButton(ns("download"), "Export real attendance CSV", class = "btn-export")),
      DT::DTOutput(ns("games_table")),
      class = "table-panel"
    )
  )
}

attendance_server <- function(id, games) {
  shiny::moduleServer(id, function(input, output, session) {
    output$metrics <- shiny::renderUI({
      df <- games()
      n <- nrow(df)
      total <- if (n) sum(df$reported_attendance) else NA_real_
      average <- if (n) mean(df$reported_attendance) else NA_real_
      utilization <- if (n) safe_ratio(total, sum(df$nominal_capacity)) else NA_real_
      shiny::tags$div(
        class = "metric-grid",
        metric_card("Total reported attendance", format_count(total), "Official NHL attendance · selected games"),
        metric_card("Average attendance", format_count(average), "Per selected PPG home game"),
        metric_card("Nominal venue utilization", format_percent(utilization), "Attendance ÷ reference venue capacity"),
        metric_card("Home games analyzed", format_count(n), "PPG Paints Arena · regular season")
      )
    })

    output$takeaway <- shiny::renderUI({
      df <- games()
      if (!nrow(df)) return(shiny::tags$p("Choose a broader filter to view an attendance summary."))
      weekends <- df[!is.na(df$is_weekend) & df$is_weekend, , drop = FALSE]
      weekdays <- df[!is.na(df$is_weekend) & !df$is_weekend, , drop = FALSE]
      if (nrow(weekends) >= 2L && nrow(weekdays) >= 2L) {
        difference <- mean(weekends$reported_attendance) - mean(weekdays$reported_attendance)
        direction <- if (difference >= 0) "above" else "below"
        return(shiny::tags$p(
          paste0("Selected weekend games averaged ", format_count(abs(difference)),
                 " attendees ", direction, " the weekday average. Check game counts before interpreting the gap.")
        ))
      }
      shiny::tags$p(paste0(nrow(df), " selected games averaged ",
                            format_count(mean(df$reported_attendance)), " reported attendees."))
    })

    output$trend <- shiny::renderPlot({
      df <- games()
      if (!nrow(df)) return(empty_plot())
      p <- ggplot2::ggplot(
        df, ggplot2::aes(x = .data$game_date, y = .data$reported_attendance)
      ) +
        ggplot2::geom_hline(yintercept = 18187, linetype = "dashed", colour = "#6D7B89") +
        ggplot2::geom_line(colour = "#B98A27", linewidth = 0.75) +
        ggplot2::geom_point(colour = PENS_GOLD, size = 2.5) +
        ggplot2::scale_y_continuous(labels = scales::comma, expand = ggplot2::expansion(mult = c(0.08, 0.1))) +
        ggplot2::labs(x = NULL, y = "Reported attendance") +
        penguins_plot_theme()
      if (dplyr::n_distinct(df$season) > 1L) {
        p <- p + ggplot2::facet_wrap(~ season, scales = "free_x", ncol = 1) +
          ggplot2::scale_x_date(date_labels = "%b", date_breaks = "2 months")
      } else {
        p <- p + ggplot2::scale_x_date(date_labels = "%b '%y", date_breaks = "4 months")
      }
      p
    }, res = 110)

    output$weekday <- shiny::renderPlot({
      df <- games()
      if (!nrow(df)) return(empty_plot())
      week <- df |>
        dplyr::mutate(weekday = factor(substr(as.character(.data$day_of_week), 1, 3), levels = WEEKDAY_ORDER)) |>
        dplyr::group_by(.data$weekday) |>
        dplyr::summarise(average = mean(.data$reported_attendance), count = dplyr::n(), .groups = "drop")
      ggplot2::ggplot(week, ggplot2::aes(x = .data$weekday, y = .data$average)) +
        ggplot2::geom_col(fill = PENS_GOLD_SOFT, width = 0.65) +
        ggplot2::geom_text(ggplot2::aes(label = paste0("n=", .data$count)),
                           vjust = 1.7, colour = "#0C1117", fontface = "bold", size = 3.5) +
        ggplot2::scale_y_continuous(labels = scales::comma, expand = ggplot2::expansion(mult = c(0, 0.14))) +
        ggplot2::labs(x = NULL, y = "Average reported attendance") +
        penguins_plot_theme()
    }, res = 110)

    output$opponents <- shiny::renderPlot({
      df <- games()
      if (!nrow(df)) return(empty_plot())
      top <- df |>
        dplyr::group_by(.data$opponent) |>
        dplyr::summarise(average = mean(.data$reported_attendance),
                         count = dplyr::n(), .groups = "drop") |>
        dplyr::arrange(dplyr::desc(.data$average), .data$opponent) |>
        utils::head(10)
      top$opponent <- factor(top$opponent, levels = rev(top$opponent))
      ggplot2::ggplot(top, ggplot2::aes(x = .data$opponent, y = .data$average)) +
        ggplot2::geom_col(fill = PENS_SKY, width = 0.69) +
        ggplot2::coord_flip() +
        ggplot2::scale_y_continuous(labels = scales::comma, expand = ggplot2::expansion(mult = c(0, 0.14))) +
        ggplot2::labs(x = NULL, y = "Average reported attendance") +
        penguins_plot_theme()
    }, res = 110)

    output$games_table <- DT::renderDT({
      df <- games()
      visible <- data.frame(
        Date = as.Date(df$game_date),
        Season = df$season,
        Opponent = df$opponent,
        Attendance = as.double(df$reported_attendance),
        `Nominal utilization` = as.double(df$nominal_utilization),
        Result = df$result,
        check.names = FALSE
      )
      table <- DT::datatable(
        visible, rownames = FALSE, filter = "none",
        options = list(pageLength = 8, lengthMenu = c(8, 15, 30),
                       order = list(list(0, "desc")), scrollX = TRUE,
                       autoWidth = TRUE, dom = "ftip"),
        class = "compact stripe hover"
      )
      DT::formatPercentage(
        DT::formatRound(table, "Attendance", digits = 0),
        "Nominal utilization", digits = 1
      )
    }, server = FALSE)

    output$download <- shiny::downloadHandler(
      filename = function() paste0("penguins_real_attendance_", Sys.Date(), ".csv"),
      content = function(file) {
        df <- games()
        export <- df[, c("game_id", "season", "game_date", "opponent", "venue",
                         "reported_attendance", "nominal_capacity", "nominal_utilization",
                         "home_goals", "away_goals", "result", "report_source_url",
                         "data_origin", "attendance_origin"), drop = FALSE]
        utils::write.csv(export, file, row.names = FALSE, na = "")
      }
    )
  })
}
