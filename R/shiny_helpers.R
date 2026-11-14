# STAGE 4A — Presentation and calculation helpers.
# Data provenance: attendance is real NHL; all sales/revenue are synthetic.

PENS_GOLD <- "#FFB81C"
PENS_GOLD_SOFT <- "#E6A51A"
PENS_SKY <- "#85BBD6"
PENS_SURFACE <- "#111A24"
PENS_MUTED <- "#9FAFBD"
SEASON_ORDER <- c("2023-24", "2024-25", "2025-26")
WEEKDAY_ORDER <- c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

format_count <- function(x) {
  if (length(x) == 0L || is.na(x)) return("—")
  scales::comma(round(x, 0), accuracy = 1)
}

format_money <- function(x) {
  if (length(x) == 0L || is.na(x)) return("—")
  if (abs(x) >= 1e6) return(paste0("$", formatC(x / 1e6, digits = 2, format = "f"), "M"))
  if (abs(x) >= 1e3) return(paste0("$", formatC(x / 1e3, digits = 1, format = "f"), "K"))
  paste0("$", formatC(x, digits = 0, format = "f", big.mark = ","))
}

format_price <- function(x) {
  if (length(x) == 0L || is.na(x)) return("—")
  scales::dollar(x, accuracy = 0.01)
}

format_percent <- function(x, accuracy = 0.1) {
  if (length(x) == 0L || is.na(x)) return("—")
  scales::percent(x, accuracy = accuracy)
}

safe_ratio <- function(num, den) {
  if (length(den) != 1L || is.na(den) || den <= 0) return(NA_real_)
  as.double(num) / as.double(den)
}

metric_card <- function(label, value, detail, kind = c("real", "synthetic")) {
  kind <- match.arg(kind)
  shiny::tags$div(
    class = paste("metric-card", paste0("metric-", kind)),
    shiny::tags$div(class = "metric-label", label),
    shiny::tags$div(class = "metric-value", value),
    shiny::tags$p(class = "metric-description", detail)
  )
}

section_panel <- function(title, subtitle = NULL, ..., class = "") {
  shiny::tags$section(
    class = paste("chart-panel", class),
    shiny::tags$div(
      class = "panel-heading",
      shiny::tags$h3(title),
      if (!is.null(subtitle)) shiny::tags$p(subtitle)
    ),
    ...
  )
}

empty_plot <- function(message = "No games match the selected filters") {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0, y = 0, label = message,
                      colour = "#D0D7DF", size = 5) +
    ggplot2::xlim(-1, 1) + ggplot2::ylim(-1, 1) +
    ggplot2::theme_void() +
    ggplot2::theme(plot.background = ggplot2::element_rect(
      fill = PENS_SURFACE, colour = NA))
}

penguins_plot_theme <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      text = ggplot2::element_text(colour = "#E9EDF1", family = "sans"),
      plot.background = ggplot2::element_rect(fill = PENS_SURFACE, colour = NA),
      panel.background = ggplot2::element_rect(fill = PENS_SURFACE, colour = NA),
      panel.grid.major = ggplot2::element_line(colour = "#293745", linewidth = 0.3),
      panel.grid.minor = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(colour = "#B8C4CF"),
      axis.title = ggplot2::element_text(colour = "#DCE3E9"),
      strip.text = ggplot2::element_text(colour = "#E9EDF1", face = "bold"),
      strip.background = ggplot2::element_rect(fill = "#1B2835", colour = NA),
      legend.position = "none",
      plot.margin = ggplot2::margin(12, 12, 14, 6)
    )
}

# Shared filters apply to both the REAL and SYNTHETIC tabs via game_id.
filter_real_games <- function(games, season = "All", opponent = "All", day_type = "All") {
  selected <- games
  if (!identical(season, "All")) {
    selected <- selected[selected$season == season, , drop = FALSE]
  }
  if (!identical(opponent, "All")) {
    selected <- selected[selected$opponent == opponent, , drop = FALSE]
  }
  if (identical(day_type, "Weekend")) {
    selected <- selected[!is.na(selected$is_weekend) & selected$is_weekend, , drop = FALSE]
  } else if (identical(day_type, "Weekday")) {
    selected <- selected[!is.na(selected$is_weekend) & !selected$is_weekend, , drop = FALSE]
  }
  selected[order(selected$game_date, selected$game_id), , drop = FALSE]
}
