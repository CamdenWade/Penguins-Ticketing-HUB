# Stage 2 / Step 3: A fast real-data preview, not the Shiny dashboard.
# Run: source("scripts/03_preview_attendance.R")

required_packages <- c("dplyr", "ggplot2", "scales", "readr")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace,
                                              logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) stop("Missing packages: ", paste(missing_packages, collapse = ", "))

input <- "data/processed/games_real.rds"
if (!file.exists(input)) stop("Validated games not found. Finish Stage 2 validation first.")
games <- readRDS(input)
ppg_games <- dplyr::filter(games, .data$is_ppg_home)
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)

p <- ggplot2::ggplot(ppg_games, ggplot2::aes(x = .data$game_date,
                                              y = .data$reported_attendance)) +
  ggplot2::geom_point(color = "#FFB81C", size = 2.2, alpha = 0.9) +
  ggplot2::geom_hline(yintercept = 18187, linetype = "dashed",
                      color = "#777777") +
  ggplot2::facet_wrap(~season, scales = "free_x", ncol = 1) +
  ggplot2::scale_y_continuous(labels = scales::comma) +
  ggplot2::labs(
    title = "Pittsburgh Penguins: Reported Home Attendance",
    subtitle = "PPG Paints Arena only | Official NHL game reports | Dashed line: nominal 18,187 capacity",
    x = NULL, y = "Reported attendance",
    caption = "Real historical attendance. Nominal capacity is a fixed reference, not a game-specific sellable inventory."
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(plot.title = ggplot2::element_text(face = "bold"),
                 strip.text = ggplot2::element_text(face = "bold"))

ggplot2::ggsave("outputs/figures/attendance_by_game.png", p,
                width = 11, height = 8, dpi = 160)
print(p)

weekday_summary <- ppg_games |>
  dplyr::group_by(.data$day_of_week) |>
  dplyr::summarise(games = dplyr::n(),
                   avg_attendance = mean(.data$reported_attendance),
                   .groups = "drop") |>
  dplyr::arrange(dplyr::desc(.data$avg_attendance))
readr::write_csv(weekday_summary, "outputs/tables/attendance_by_weekday.csv")
print(weekday_summary)
message("Stage 2 preview saved: outputs/figures/attendance_by_game.png")
