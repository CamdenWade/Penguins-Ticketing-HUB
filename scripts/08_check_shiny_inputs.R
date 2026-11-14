# STAGE 4A — Preflight before launching Shiny.
# Run from project root: source("scripts/08_check_shiny_inputs.R")

required_packages <- c("shiny", "bslib", "dplyr", "ggplot2", "scales", "DT")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop("Install Stage 4A packages: ", paste(missing_packages, collapse = ", "))
}

source("R/shiny_data.R")
source("R/shiny_helpers.R")
preflight <- load_stage4a_data()
stopifnot(nrow(preflight$real) == 122L)
stopifnot(nrow(preflight$business) == 122L)
stopifnot(nrow(preflight$category) == 488L)
stopifnot(!anyNA(preflight$real$reported_attendance))

season_summary <- preflight$business |>
  dplyr::group_by(.data$season) |>
  dplyr::summarise(
    games = dplyr::n(),
    sim_paid_tickets = sum(.data$sim_paid_tickets),
    sim_revenue_usd = sum(as.double(.data$sim_ticket_revenue_cents)) / 100,
    sim_sellthrough = sum(.data$sim_paid_tickets) / sum(.data$sellable_seats),
    .groups = "drop"
  )

message("PASS — Stage 4A preflight.")
message("  Real PPG games: ", nrow(preflight$real))
message("  Synthetic game summaries: ", nrow(preflight$business))
message("  Game × seat-category aggregates: ", nrow(preflight$category))
message("  Game × channel aggregates: ", nrow(preflight$channel))
print(season_summary)
message("Next: shiny::runApp() or click 'Run App' on app.R")
