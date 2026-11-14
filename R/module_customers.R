# STAGE 4B — Synthetic customers, memberships and retention.
# Uses validated pre-aggregated objects from load_stage4b_data().
# Season applies to all panels. Opponent/weekend filters apply ONLY to
# "selected game" panels; full-season cohort panels are season-level.

customers_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$div(
    class = "dashboard-page customer-page",
    shiny::tags$section(
      class = "page-intro",
      shiny::tags$div(
        shiny::tags$div(class = "eyebrow", "FAN INTELLIGENCE  /  03"),
        shiny::tags$h1("Customer & Membership Analytics"),
        shiny::tags$p("Examine illustrative customer engagement, account value, membership renewals and purchasing cohorts." )
      ),
      shiny::tags$span(class = "data-pill synthetic-pill", "SYNTHETIC CRM DATA")
    ),
    shiny::tags$div(
      class = "note-banner synthetic-note",
      shiny::tags$strong("Simulated customer records only"),
      "These are anonymous generated customer accounts, membership contracts and purchases — not Penguins CRM data. Ticket entitlements do not prove game attendance."
    ),
    shiny::tags$div(
      class = "subsection-heading",
      shiny::tags$div(class = "eyebrow", "SELECTED GAMES"),
      shiny::tags$h2("Customer activity in the current game filter"),
      shiny::tags$p("Season, opponent and weekday filters apply here. Metrics include season-ticket game rights as well as single-game and group orders.")
    ),
    shiny::uiOutput(ns("game_kpis")),
    shiny::tags$div(
      class = "chart-grid chart-grid-main",
      section_panel("Illustrative revenue by fan segment",
                    "Game-level synthetic earned revenue, not lifetime value",
                    shiny::plotOutput(ns("segment_chart"), height = "350px")),
      section_panel("Games represented per account",
                    "Distinct selected games with paid ticket entitlements",
                    shiny::plotOutput(ns("engagement_chart"), height = "350px"))
    ),
    section_panel(
      "Selected-game customer segment breakdown",
      "Accounts are distinct within the selected games; revenue is allocated game-level revenue",
      shiny::tags$div(class = "table-actions",
                      shiny::downloadButton(ns("segment_export"), "Export synthetic segment CSV",
                                            class = "btn-export")),
      DT::DTOutput(ns("segment_table")),
      class = "table-panel"
    ),
    shiny::tags$div(
      class = "subsection-heading subsection-spaced",
      shiny::tags$div(class = "eyebrow", "FULL-SEASON CUSTOMER COHORTS"),
      shiny::tags$h2("Renewal & retention intelligence"),
      shiny::tags$p("Only the season filter applies below. Opponent and weekday selections do not alter full-season membership and purchaser retention denominators.")
    ),
    shiny::uiOutput(ns("cohort_kpis")),
    shiny::tags$div(
      class = "chart-grid chart-grid-main",
      section_panel("Membership renewal & purchaser retention",
                    "Prior-season eligible cohort denominators; 2023–24 has no observed prior season",
                    shiny::plotOutput(ns("retention_chart"), height = "340px")),
      section_panel("First-observed, retained & reactivated purchasers",
                    "Full-season account statuses within the simulated observation window",
                    shiny::plotOutput(ns("status_chart"), height = "340px"))
    ),
    shiny::tags$div(
      class = "chart-grid chart-grid-main",
      section_panel("Synthetic order frequency",
                    "Number of distinct purchase orders per active customer-season; season passes count once",
                    shiny::plotOutput(ns("frequency_chart"), height = "340px")),
      section_panel("What a business team could do",
                    "Interpretation and customer-data caveats",
                    shiny::tags$div(class = "insight-list",
                                    shiny::tags$div("01", shiny::tags$span("Identify customer segments contributing meaningful hypothetical earned revenue.")),
                                    shiny::tags$div("02", shiny::tags$span("Monitor prior-year membership cohorts ahead of renewal campaigns.")),
                                    shiny::tags$div("03", shiny::tags$span("Compare first-observed and returning purchasers to shape acquisition versus loyalty efforts."))),
                    shiny::tags$div(class = "live-takeaway", shiny::uiOutput(ns("takeaway"))),
                    shiny::tags$p(class = "insight-caveat",
                                  "The simulation creates purchasing/renewal behavior. It cannot establish actual fan loyalty or promotion effectiveness."))
    ),
    section_panel(
      "Full-season cohort audit table",
      "First season is baseline only; blank prior-year rates mean unavailable, not zero",
      shiny::tags$div(class = "table-actions",
                      shiny::downloadButton(ns("cohort_export"), "Export synthetic cohort CSV",
                                            class = "btn-export")),
      DT::DTOutput(ns("cohort_table")),
      class = "table-panel"
    )
  )
}

customers_server <- function(id, customer_data, selected_ids, season_filter) {
  shiny::moduleServer(id, function(input, output, session) {
    selected_activity <- shiny::reactive({
      x <- customer_data$game_accounts
      x[x$game_id %in% selected_ids(), , drop = FALSE]
    })
    seasons_selected <- shiny::reactive({
      season <- season_filter()
      if (identical(season, "All")) SEASON_ORDER else season
    })
    selected_cohorts <- shiny::reactive({
      x <- customer_data$cohorts
      x[x$season %in% seasons_selected(), , drop = FALSE]
    })
    selected_orders <- shiny::reactive({
      x <- customer_data$account_season
      x[x$season %in% seasons_selected(), , drop = FALSE]
    })
    segment_summary <- shiny::reactive({
      df <- selected_activity()
      if (!nrow(df)) return(data.frame(
        fan_segment = character(), unique_accounts = integer(),
        game_entitlements = integer(), paid_tickets = double(),
        earned_revenue_cents = double(), revenue_per_account = double()
      ))
      df |>
        dplyr::group_by(.data$fan_segment) |>
        dplyr::summarise(
          unique_accounts = dplyr::n_distinct(.data$customer_id),
          game_entitlements = dplyr::n(),
          paid_tickets = sum(.data$paid_tickets),
          earned_revenue_cents = sum(.data$earned_revenue_cents),
          .groups = "drop"
        ) |>
        dplyr::mutate(
          revenue_per_account = .data$earned_revenue_cents / 100 / .data$unique_accounts
        ) |>
        dplyr::arrange(dplyr::desc(.data$earned_revenue_cents))
    })

    output$game_kpis <- shiny::renderUI({
      df <- selected_activity()
      unique_accounts <- dplyr::n_distinct(df$customer_id)
      revenue <- sum(df$earned_revenue_cents) / 100
      tickets <- sum(df$paid_tickets)
      game_counts <- if (nrow(df)) table(df$customer_id) else numeric(0)
      multigame <- safe_ratio(sum(game_counts >= 2), unique_accounts)
      shiny::tags$div(class = "metric-grid",
                      metric_card("Accounts with tickets", format_count(unique_accounts),
                                  "Distinct synthetic accounts with rights in selected games", "synthetic"),
                      metric_card("Earned revenue per account", format_price(safe_ratio(revenue, unique_accounts)),
                                  "Simulated game revenue ÷ distinct accounts", "synthetic"),
                      metric_card("Paid tickets per account", if (unique_accounts > 0)
                        sprintf("%.1f", tickets / unique_accounts) else "—",
                                  "Game-level allocated tickets ÷ accounts", "synthetic"),
                      metric_card("Multi-game account share", format_percent(multigame),
                                  "Accounts with tickets for ≥2 selected games", "synthetic"))
    })
    output$segment_chart <- shiny::renderPlot({
      df <- segment_summary()
      if (!nrow(df)) return(empty_plot("No synthetic accounts match these games"))
      df$fan_segment <- factor(df$fan_segment, levels = rev(df$fan_segment))
      ggplot2::ggplot(df, ggplot2::aes(x = .data$fan_segment,
                                      y = .data$earned_revenue_cents / 100)) +
        ggplot2::geom_col(width = 0.62, fill = PENS_GOLD) +
        ggplot2::coord_flip() +
        ggplot2::scale_y_continuous(labels = scales::label_dollar(scale = 1e-6,
                                    suffix = "M", accuracy = 0.1),
                                    expand = ggplot2::expansion(mult = c(0, 0.12))) +
        ggplot2::labs(x = NULL, y = "Synthetic earned revenue (USD)") +
        penguins_plot_theme()
    }, res = 110)
    output$engagement_chart <- shiny::renderPlot({
      df <- selected_activity()
      if (!nrow(df)) return(empty_plot("No accounts match these games"))
      frequencies <- df |>
        dplyr::count(.data$customer_id, name = "games") |>
        dplyr::mutate(bucket = dplyr::case_when(
          .data$games == 1 ~ "1 game", .data$games <= 4 ~ "2–4",
          .data$games <= 9 ~ "5–9", TRUE ~ "10+")) |>
        dplyr::count(.data$bucket, name = "accounts")
      frequencies$bucket <- factor(frequencies$bucket,
                                   levels = c("1 game", "2–4", "5–9", "10+"))
      ggplot2::ggplot(frequencies, ggplot2::aes(x = .data$bucket, y = .data$accounts)) +
        ggplot2::geom_col(fill = PENS_SKY, width = 0.65) +
        ggplot2::scale_y_continuous(labels = scales::comma,
                                    expand = ggplot2::expansion(mult = c(0, 0.15))) +
        ggplot2::labs(x = "Distinct selected games", y = "Synthetic accounts") +
        penguins_plot_theme()
    }, res = 110)

    output$segment_table <- DT::renderDT({
      df <- segment_summary()
      view <- data.frame(
        Segment = df$fan_segment,
        Accounts = df$unique_accounts,
        `Game entitlements` = df$game_entitlements,
        `Paid tickets (sim)` = df$paid_tickets,
        `Earned revenue (sim)` = df$earned_revenue_cents / 100,
        `Revenue/account (sim)` = df$revenue_per_account,
        check.names = FALSE
      )
      widget <- DT::datatable(view, rownames = FALSE,
                              options = list(pageLength = 5, dom = "t", scrollX = TRUE),
                              class = "compact stripe hover")
      widget <- DT::formatRound(widget, c("Accounts", "Game entitlements", "Paid tickets (sim)"), 0)
      DT::formatCurrency(widget, c("Earned revenue (sim)", "Revenue/account (sim)"), "$", digits = 2)
    }, server = FALSE)
    output$segment_export <- shiny::downloadHandler(
      filename = function() paste0("penguins_SYNTHETIC_customer_segments_", Sys.Date(), ".csv"),
      content = function(file) {
        x <- segment_summary()
        x$data_origin <- "SYNTHETIC"
        utils::write.csv(x, file, row.names = FALSE)
      }
    )

    output$cohort_kpis <- shiny::renderUI({
      cohort <- selected_cohorts()
      eligible_members <- sum(cohort$membership_eligible, na.rm = TRUE)
      renewed <- sum(cohort$renewed_members, na.rm = TRUE)
      eligible_buyers <- sum(cohort$retention_eligible, na.rm = TRUE)
      retained <- sum(cohort$retained_accounts, na.rm = TRUE)
      annual <- selected_orders()
      avg_orders <- safe_ratio(sum(annual$distinct_orders), nrow(annual))
      first_share <- safe_ratio(sum(cohort$first_observed), sum(cohort$active_accounts))
      shiny::tags$div(
        class = "metric-grid cohort-metric-grid",
        metric_card("Membership renewal rate", format_percent(safe_ratio(renewed, eligible_members)),
                    "Renewed prior-season members ÷ eligible prior-season members", "synthetic"),
        metric_card("Purchaser retention rate", format_percent(safe_ratio(retained, eligible_buyers)),
                    "Prior-season purchasers returning in the next season", "synthetic"),
        metric_card("First-observed account share", format_percent(first_share),
                    "First purchase in the three-season simulated window", "synthetic"),
        metric_card("Orders per active account-season",
                    if (is.na(avg_orders)) "—" else sprintf("%.1f", avg_orders),
                    "Orders count membership contracts once", "synthetic")
      )
    })
    output$retention_chart <- shiny::renderPlot({
      c <- selected_cohorts()
      c <- c[!is.na(c$membership_eligible), , drop = FALSE]
      if (!nrow(c)) return(empty_plot("2023–24 is the first observed season; prior-year retention is unavailable"))
      chart <- rbind(
        data.frame(season = c$season, metric = "Member renewal", rate = c$member_renewal),
        data.frame(season = c$season, metric = "Purchaser retention", rate = c$purchaser_retention)
      )
      chart$season <- factor(chart$season, levels = SEASON_ORDER)
      ggplot2::ggplot(chart, ggplot2::aes(x = .data$season, y = .data$rate,
                                         fill = .data$metric)) +
        ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.7), width = 0.62) +
        ggplot2::scale_fill_manual(values = c("Member renewal" = PENS_GOLD,
                                               "Purchaser retention" = PENS_SKY)) +
        ggplot2::scale_y_continuous(labels = scales::percent, limits = c(0, 1),
                                    expand = ggplot2::expansion(mult = c(0, 0.04))) +
        ggplot2::labs(x = NULL, y = "Eligible cohort rate", fill = NULL) +
        penguins_plot_theme() +
        ggplot2::theme(legend.position = "bottom", legend.text = ggplot2::element_text(
          colour = "#C9D5DF"))
    }, res = 110)
    output$status_chart <- shiny::renderPlot({
      c <- selected_cohorts()
      if (!nrow(c)) return(empty_plot())
      chart <- rbind(
        data.frame(season = c$season, status = "First observed", accounts = c$first_observed),
        data.frame(season = c$season, status = "Retained", accounts = c$retained_from_prior),
        data.frame(season = c$season, status = "Reactivated", accounts = c$reactivated)
      )
      chart$season <- factor(chart$season, levels = SEASON_ORDER)
      ggplot2::ggplot(chart, ggplot2::aes(x = .data$season, y = .data$accounts,
                                         fill = .data$status)) +
        ggplot2::geom_col(width = 0.67) +
        ggplot2::scale_fill_manual(values = c("First observed" = PENS_GOLD,
                                               "Retained" = PENS_SKY,
                                               "Reactivated" = "#8B86B4")) +
        ggplot2::scale_y_continuous(labels = scales::comma,
                                    expand = ggplot2::expansion(mult = c(0, 0.12))) +
        ggplot2::labs(x = NULL, y = "Synthetic active accounts", fill = NULL) +
        penguins_plot_theme() +
        ggplot2::theme(legend.position = "bottom", legend.text = ggplot2::element_text(
          colour = "#C9D5DF"))
    }, res = 110)
    output$frequency_chart <- shiny::renderPlot({
      df <- selected_orders()
      if (!nrow(df)) return(empty_plot("No synthetic orders available"))
      freq <- df |>
        dplyr::mutate(order_group = dplyr::case_when(
          .data$distinct_orders == 1 ~ "1 order",
          .data$distinct_orders <= 3 ~ "2–3",
          .data$distinct_orders <= 9 ~ "4–9",
          TRUE ~ "10+")) |>
        dplyr::count(.data$order_group, name = "account_seasons")
      freq$order_group <- factor(freq$order_group, levels = c("1 order", "2–3", "4–9", "10+"))
      ggplot2::ggplot(freq, ggplot2::aes(x = .data$order_group, y = .data$account_seasons)) +
        ggplot2::geom_col(fill = PENS_GOLD_SOFT, width = 0.67) +
        ggplot2::scale_y_continuous(labels = scales::comma,
                                    expand = ggplot2::expansion(mult = c(0, 0.14))) +
        ggplot2::labs(x = "Orders per customer-season", y = "Active customer-season records") +
        penguins_plot_theme()
    }, res = 110)
    output$takeaway <- shiny::renderUI({
      seg <- segment_summary()
      c <- selected_cohorts()
      if (!nrow(seg)) return(shiny::tags$p("Expand your game filter to see segment opportunities."))
      first <- as.character(seg$fan_segment[1])
      eligible <- sum(c$membership_eligible, na.rm = TRUE)
      ren <- sum(c$renewed_members, na.rm = TRUE)
      renewal_text <- if (eligible > 0) paste0(" The full-season eligible member renewal rate is ",
                                               format_percent(ren / eligible), ".") else
        " The first observed season does not have a prior membership cohort."
      shiny::tags$p(paste0(
        "Among selected games, ", first,
        " contributes the largest share of simulated segment revenue.", renewal_text,
        " These patterns are illustrative and are not evidence of actual Penguins customer behavior."
      ))
    })
    output$cohort_table <- DT::renderDT({
      c <- selected_cohorts()
      df <- data.frame(
        Season = c$season,
        `Active purchasers` = c$active_accounts,
        `First observed` = c$first_observed,
        `Retained purchasers` = c$retained_from_prior,
        `Reactivated` = c$reactivated,
        `Member renewal rate` = vapply(c$member_renewal, function(x)
          if (is.na(x)) "N/A" else scales::percent(x, accuracy = 0.1), character(1)),
        `Purchaser retention` = vapply(c$purchaser_retention, function(x)
          if (is.na(x)) "N/A" else scales::percent(x, accuracy = 0.1), character(1)),
        check.names = FALSE
      )
      t <- DT::datatable(df, rownames = FALSE,
                         options = list(pageLength = 5, dom = "t", scrollX = TRUE),
                         class = "compact stripe hover")
      t <- DT::formatRound(t, c("Active purchasers", "First observed", "Retained purchasers", "Reactivated"), 0)
      t
    }, server = FALSE)
    output$cohort_export <- shiny::downloadHandler(
      filename = function() paste0("penguins_SYNTHETIC_customer_cohorts_", Sys.Date(), ".csv"),
      content = function(file) utils::write.csv(selected_cohorts(), file, row.names = FALSE)
    )
  })
}
