# STAGE 3: Exploratory business KPI preview (not a Shiny dashboard).
# source("scripts/06_preview_synthetic_kpis.R")
if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2 first.")
if (!requireNamespace("scales", quietly = TRUE)) stop("Install scales first.")

summary_path <- "data/synthetic/game_business_summary.rds"
if (!file.exists(summary_path)) stop("Run and pass script 05 first.")
games <- readRDS(summary_path)
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)

revenue <- aggregate(sim_ticket_revenue_cents ~ season, games, sum)
revenue$sim_ticket_revenue_usd <- revenue$sim_ticket_revenue_cents / 100
attendance <- aggregate(reported_attendance ~ season, games, mean)
names(attendance)[2] <- "real_average_ppg_attendance"
season_kpis <- merge(revenue, attendance, by = "season")
write.csv(season_kpis, "outputs/tables/stage3_season_kpi_preview.csv", row.names = FALSE)
print(season_kpis, row.names = FALSE)

p <- ggplot2::ggplot(games, ggplot2::aes(x = game_date, y = sim_ticket_revenue_cents / 100)) +
  ggplot2::geom_col(fill = "#FFB81C", width = 3) +
  ggplot2::facet_wrap(~ season, ncol = 1, scales = "free_x") +
  ggplot2::scale_y_continuous(labels = scales::label_dollar(scale = 1e-6, suffix = "M")) +
  ggplot2::labs(
    title = "Illustrative Penguins Home-Game Ticket Revenue",
    subtitle = "SYNTHETIC transactions; real NHL game dates (PPG Paints Arena only)",
    x = NULL, y = "Synthetic net ticket revenue (USD)",
    caption = "Not actual Pittsburgh Penguins ticket sales, revenue, or pricing."
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(plot.title = ggplot2::element_text(face = "bold"),
                 strip.text = ggplot2::element_text(face = "bold"))

ggplot2::ggsave("outputs/figures/stage3_synthetic_revenue_by_game.png",
                p, width = 11, height = 8, dpi = 150)
print(p)
message("Stage 3 KPI preview saved to outputs/figures/.")
