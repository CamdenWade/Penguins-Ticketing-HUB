# Stage 5A, Step 3 — make honest, held-out TEST diagnostics (2025-26).
# Existing Shiny app and source RDS files are not modified.
source("R/attendance_model_helpers.R")
if (!requireNamespace("ggplot2", quietly = TRUE) ||
    !requireNamespace("scales", quietly = TRUE)) {
  stop("Install ggplot2 and scales, or rerun scripts/07_install_shiny_packages.R",
       call. = FALSE)
}
if (!file.exists("models/attendance_model_bundle.rds") ||
    !file.exists("data/modeling/attendance_holdout_predictions.rds")) {
  stop("Run Stage 5A script 11 first.", call. = FALSE)
}
bundle <- readRDS("models/attendance_model_bundle.rds")
pred <- readRDS("data/modeling/attendance_holdout_predictions.rds")
pred$game_date <- as.Date(pred$game_date)
if (nrow(pred) != 40L || anyNA(pred$predicted_selected) ||
    !identical(unique(pred$season), "2025-26")) {
  stop("Test prediction diagnostics input is incomplete.", call. = FALSE)
}

# Charts deliberately distinguish actual NHL results from historical backtests.
GOLD <- "#FFB81C"
INK <- "#0F1722"
TEAL <- "#4C9F96"
GRAY <- "#697586"

model_title <- if (bundle$selected_model == "ridge") {
  paste0("Regularized attendance regression (lambda = ", bundle$selected_lambda, ")")
} else {
  "Historical average attendance baseline"
}

format_count <- function(x) scales::comma(x, accuracy = 1)
current_metrics <- attendance_metrics(pred$actual_attendance, pred$predicted_selected)

chart_theme <- function() {
  ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", color = INK, size = 17),
      plot.subtitle = ggplot2::element_text(color = GRAY, size = 11),
      plot.caption = ggplot2::element_text(color = GRAY, size = 9),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "bottom",
      legend.title = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(color = INK),
      axis.title = ggplot2::element_text(color = INK)
    )
}

# Plot 1 — Actual versus the one pre-selected model, in game-date order.
long <- rbind(
  data.frame(game_date = pred$game_date,
             attendance = pred$actual_attendance,
             series = "Actual NHL attendance"),
  data.frame(game_date = pred$game_date,
             attendance = pred$predicted_selected,
             series = "Holdout prediction")
)
long$series <- factor(long$series,
                      levels = c("Actual NHL attendance", "Holdout prediction"))
p_time <- ggplot2::ggplot(long, ggplot2::aes(x = game_date, y = attendance,
                                             color = series, group = series)) +
  ggplot2::geom_line(linewidth = 0.8, alpha = 0.9) +
  ggplot2::geom_point(size = 1.8) +
  ggplot2::scale_color_manual(values = c(
    "Actual NHL attendance" = INK, "Holdout prediction" = GOLD
  )) +
  ggplot2::scale_y_continuous(labels = format_count) +
  ggplot2::scale_x_date(date_labels = "%b %Y", date_breaks = "1 month") +
  ggplot2::labs(
    title = "2025–26: Actual vs. backtested attendance",
    subtitle = paste("40 PPG Paints Arena home games | Selected on 2024–25:", model_title),
    x = NULL, y = "Reported attendance (fans)",
    caption = "Actual = official NHL reports; predictions = pregame features trained on 2023–25. Stockholm excluded."
  ) + chart_theme() +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))

# Plot 2 — Distance from perfect predictions.
p_scatter <- ggplot2::ggplot(
  pred,
  ggplot2::aes(x = actual_attendance, y = predicted_selected)
) +
  ggplot2::geom_abline(slope = 1, intercept = 0,
                       linetype = "dashed", color = GRAY) +
  ggplot2::geom_point(color = GOLD, size = 3, alpha = 0.8) +
  ggplot2::coord_equal() +
  ggplot2::scale_x_continuous(labels = format_count) +
  ggplot2::scale_y_continuous(labels = format_count) +
  ggplot2::labs(
    title = "Held-out prediction accuracy",
    subtitle = sprintf("MAE: %s fans/game  |  RMSE: %s fans/game",
                       format_count(current_metrics$mae), format_count(current_metrics$rmse)),
    x = "Actual NHL attendance", y = "Predicted attendance",
    caption = "Dashed diagonal = perfect prediction; observations = 2025–26 arena games."
  ) + chart_theme()

# Plot 3 — Signed forecast errors in chronological order.
p_errors <- ggplot2::ggplot(
  pred,
  ggplot2::aes(x = game_date, y = residual_actual_minus_predicted)
) +
  ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = GRAY) +
  ggplot2::geom_col(fill = TEAL, width = 4) +
  ggplot2::scale_y_continuous(labels = format_count) +
  ggplot2::scale_x_date(date_labels = "%b %Y", date_breaks = "1 month") +
  ggplot2::labs(
    title = "Where the selected model missed",
    subtitle = "Positive residual = actual attendance exceeded prediction",
    x = NULL, y = "Actual minus predicted (fans)",
    caption = "Residuals are descriptive backtest errors, not causal effects or demand estimates."
  ) + chart_theme() +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))

dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)
ggplot2::ggsave("outputs/figures/stage5a_actual_vs_predicted.png",
                p_time, width = 12, height = 6.1, dpi = 170)
ggplot2::ggsave("outputs/figures/stage5a_accuracy_scatter.png",
                p_scatter, width = 8, height = 7, dpi = 170)
ggplot2::ggsave("outputs/figures/stage5a_residuals_by_game.png",
                p_errors, width = 12, height = 6.1, dpi = 170)

# Small, descriptive subgroup report; not suitable for strong generalizations.
month_split <- split(pred, pred$calendar_month)
month_report <- do.call(rbind, lapply(names(month_split), function(mon) {
  p <- month_split[[mon]]
  data.frame(
    calendar_month = as.integer(mon),
    games = nrow(p),
    actual_mean = mean(p$actual_attendance),
    predicted_mean = mean(p$predicted_selected),
    mae = mean(p$absolute_error),
    bias_pred_minus_actual = mean(p$predicted_selected - p$actual_attendance)
  )
}))
month_report <- month_report[order(month_report$calendar_month), , drop = FALSE]
write_model_csv(month_report, "outputs/tables/stage5a_holdout_error_by_month.csv")

cat("PASS — Stage 5A diagnostic figures and monthly error report saved.\n")
cat("Selected model:", bundle$selected_model, "\n")
print(current_metrics, row.names = FALSE)
cat("Next: source('scripts/13_validate_attendance_models.R')\n")
