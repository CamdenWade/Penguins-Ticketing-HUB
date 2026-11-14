# STAGE 5B — Preflight for Shiny historical backtest + synthetic what-if tab.
# Run from Penguins-Ticketing-HUB project root:
# source("scripts/14_check_forecast_dashboard.R")
# This script DOES NOT change earlier validated RDS files or fitted models.

required <- c("dplyr", "ggplot2", "scales", "shiny", "bslib", "DT")
missing_packages <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) {
  stop("Missing packages: ", paste(missing_packages, collapse = ", "),
       ". Run source('scripts/07_install_shiny_packages.R')", call. = FALSE)
}

source("R/shiny_helpers.R")
source("R/shiny_data.R")
source("R/shiny_opportunity_helpers.R")
source("R/shiny_forecast_data.R")

# Retain MD5 checksums to prove this stage leaves validated inputs untouched.
protected <- c("data/processed/games_real.rds",
               "data/synthetic/game_business_summary.rds",
               "models/attendance_model_bundle.rds",
               "data/modeling/attendance_holdout_predictions.rds")
if (any(!file.exists(protected))) stop("Stage 2/3/5A source file missing.", call. = FALSE)
md5_before <- unname(tools::md5sum(protected))

hub <- load_stage4a_data()
backtest <- load_stage5b_data(hub)
selected <- backtest$selected_model
pred <- backtest$predictions
metrics <- backtest$metrics
all_business <- hub$business
scenario_zero <- calculate_ticket_opportunity(all_business, 0, 90, 10)
scenario_default <- calculate_ticket_opportunity(all_business, 15, 90, 10)
scenario_full <- calculate_ticket_opportunity(all_business, 100, 90, 10)
totals <- summarize_ticket_opportunity(scenario_default)

checks <- data.frame(check = character(), expected = character(),
                     actual = character(), passed = logical(),
                     stringsAsFactors = FALSE)
check_it <- function(name, expected, actual, passed) {
  checks <<- rbind(checks, data.frame(
    check = name, expected = as.character(expected),
    actual = as.character(actual), passed = isTRUE(passed),
    stringsAsFactors = FALSE
  ))
}

# Data lineage and precommitted historical model-selection audit
check_it("Real PPG games", 122, nrow(hub$real), nrow(hub$real) == 122L)
check_it("Synthetic game summaries", 122, nrow(all_business), nrow(all_business) == 122L)
check_it("Four seating categories per game", 488, nrow(hub$category),
         nrow(hub$category) == 488L)
check_it("Three channels per game", 366, nrow(hub$channel),
         nrow(hub$channel) == 366L)
check_it("Holdout rows", 40, nrow(pred), nrow(pred) == 40L)
check_it("Holdout games unique", 40, length(unique(pred$game_id)),
         !anyDuplicated(pred$game_id))
check_it("Holdout season", "2025-26", paste(unique(pred$season), collapse = ","),
         identical(unique(as.character(pred$season)), "2025-26"))
check_it("Model outcome origin", "REAL_NHL", paste(unique(pred$data_origin), collapse = ","),
         all(pred$data_origin == "REAL_NHL"))
check_it("Precommitted selection preserved", "historical_mean", selected,
         identical(selected, "historical_mean"))
check_it("Training game IDs count", 82, 82,
         length(readRDS("models/attendance_model_bundle.rds")$training_game_ids) == 82L)
check_it("Holdout metrics cover two models", 2, nrow(metrics),
         nrow(metrics) == 2L && setequal(metrics$model, c("historical_mean", "ridge")))
check_it("Selected model flagged once", 1, sum(metrics$selected_on_validation),
         sum(metrics$selected_on_validation) == 1L &&
           metrics$model[metrics$selected_on_validation] == selected)
check_it("Original NHL game IDs agree", "40 matched", length(intersect(pred$game_id, hub$real$game_id)),
         all(pred$game_id %in% hub$real$game_id))
i_real <- match(pred$game_id, hub$real$game_id)
check_it("Real NHL attendance is unchanged", "40 equal", "joined by game_id",
         all(as.numeric(pred$actual_attendance) ==
               as.numeric(hub$real$reported_attendance[i_real])))
check_it("Selected prediction equals baseline", "max diff <1e-6",
         round(max(abs(pred$predicted_selected - pred$predicted_historical_mean)), 8),
         all(abs(pred$predicted_selected - pred$predicted_historical_mean) < 1e-6))
check_it("Row-level absolute errors reconcile", "max diff <1e-6",
         round(max(abs(pred$absolute_error -
                         abs(pred$actual_attendance - pred$predicted_selected))), 8),
         all(abs(pred$absolute_error -
                   abs(pred$actual_attendance - pred$predicted_selected)) < 1e-6))

for (m in c("historical_mean", "ridge")) {
  errors <- pred[[paste0("predicted_", m)]] - pred$actual_attendance
  saved <- metrics[metrics$model == m, , drop = FALSE]
  check_it(paste(m, "MAE matches"), "within 1e-6", round(saved$mae, 6),
           abs(mean(abs(errors)) - saved$mae) < 1e-6)
  check_it(paste(m, "RMSE matches"), "within 1e-6", round(saved$rmse, 6),
           abs(sqrt(mean(errors^2)) - saved$rmse) < 1e-6)
}

# Simulator reconciliation, inventory limits and filtered-game behavior
check_it("All scenario game IDs unique", 122, length(unique(scenario_default$game_id)),
         !anyDuplicated(scenario_default$game_id))
check_it("Scenario IDs match existing games", "exact", "set equal",
         setequal(scenario_default$game_id, all_business$game_id))
check_it("Scenario data marked synthetic", "SYNTHETIC",
         paste(unique(scenario_default$financial_data_origin), collapse = ","),
         all(scenario_default$financial_data_origin == "SYNTHETIC"))
check_it("Scenario labeled as assumptions", "USER_ASSUMPTIONS_NOT_A_FORECAST",
         paste(unique(scenario_default$scenario_origin), collapse = ","),
         all(scenario_default$scenario_origin == "USER_ASSUMPTIONS_NOT_A_FORECAST"))
check_it("Zero capture adds zero tickets", 0, sum(scenario_zero$scenario_extra_tickets),
         all(scenario_zero$scenario_extra_tickets == 0))
check_it("Zero capture adds zero revenue", 0, sum(scenario_zero$scenario_added_revenue_cents),
         all(scenario_zero$scenario_added_revenue_cents == 0))
check_it("Full capture fills all unsold seats", "exact equality", "compared by game",
         all(scenario_full$scenario_extra_tickets == scenario_full$sim_unsold_seats))
check_it("Full capture never exceeds capacity", "all exact capacity", "compared by game",
         all(scenario_full$scenario_total_paid_tickets == scenario_full$sim_sellable_seats))
check_it("Default per-game conversion rounds down", "floor(unsold*0.15)", "compared by game",
         all(scenario_default$scenario_extra_tickets ==
               floor(scenario_default$sim_unsold_seats * 0.15 + 1e-10)))
check_it("No scenario overfills inventory", "all <= sellable", "compared by game",
         all(scenario_default$scenario_total_paid_tickets <=
               scenario_default$sim_sellable_seats))
check_it("No negative unsold tickets", "all >= 0", "compared by game",
         all(scenario_default$sim_unsold_seats >= 0))
check_it("Gross revenue exact to cents", "extra*9000 cents", "compared by game",
         all(scenario_default$scenario_added_revenue_cents ==
               scenario_default$scenario_extra_tickets * 9000))
check_it("Campaign spend exact to cents", "extra*1000 cents", "compared by game",
         all(scenario_default$scenario_marketing_spend_cents ==
               scenario_default$scenario_extra_tickets * 1000))
check_it("Contribution arithmetic exact", "gross less spend", "compared by game",
         all(scenario_default$scenario_revenue_less_assumed_marketing_cents ==
               scenario_default$scenario_added_revenue_cents -
                 scenario_default$scenario_marketing_spend_cents))
check_it("Current revenue is unchanged", "matches base cents", "joined by game_id",
         all(scenario_default$sim_existing_revenue_cents ==
               as.numeric(all_business$sim_ticket_revenue_cents[
                 match(scenario_default$game_id, all_business$game_id)])))
check_it("Weighted scenario sellthrough correct", "from totals", round(totals$scenario_sellthrough, 7),
         abs(totals$scenario_sellthrough -
               (totals$current_tickets + totals$extra) / totals$sellable) < 1e-12)
check_it("Scenario sellthrough never exceeds 100%", "all <=1", "compared by game",
         all(scenario_default$scenario_sellthrough <= 1 + 1e-12))
check_it("Revenue bridge reconciles", "existing + added", "compared in cents",
         all(scenario_default$scenario_total_revenue_cents ==
               scenario_default$sim_existing_revenue_cents +
                 scenario_default$scenario_added_revenue_cents))

# Simulate filter behavior without changing global Shiny input states.
sub_business <- all_business[all_business$season == "2025-26", , drop = FALSE]
sub_scenario <- calculate_ticket_opportunity(sub_business, 15, 90, 10)
check_it("Season filter has 40 scenario games", 40, nrow(sub_scenario),
         nrow(sub_scenario) == 40L)
check_it("Season filter preserves game IDs", "all 2025-26", "verified",
         setequal(sub_scenario$game_id, sub_business$game_id))
check_it("Past seasons have no held-out rows", 0,
         sum(pred$game_id %in% all_business$game_id[all_business$season == "2024-25"]),
         !any(pred$game_id %in% all_business$game_id[all_business$season == "2024-25"]))
check_it("All 2025-26 PPG games match holdout", 40,
         sum(pred$game_id %in% sub_business$game_id),
         setequal(pred$game_id, sub_business$game_id))
empty_scenario <- calculate_ticket_opportunity(all_business[0, , drop = FALSE], 15, 90, 10)
check_it("Empty filter handled safely", 0, summarize_ticket_opportunity(empty_scenario)$games,
         nrow(empty_scenario) == 0L && summarize_ticket_opportunity(empty_scenario)$games == 0L)

md5_after <- unname(tools::md5sum(protected))
check_it("Protected RDS inputs unchanged", "identical MD5", "compared before/after",
         identical(md5_before, md5_after))

out <- "outputs/tables/stage5b_dashboard_checks.csv"
dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
utils::write.csv(checks, out, row.names = FALSE)
cat("\nStage 5B preflight checks:", sum(checks$passed), "/", nrow(checks), "passed.\n")
if (!all(checks$passed)) {
  print(checks[!checks$passed, , drop = FALSE], row.names = FALSE)
  stop("Stage 5B preflight FAILED; inspect ", out, call. = FALSE)
}
cat("PASS — Stage 5B preflight. Original data and fitted models remain unchanged.\n")
cat("Selected historical model:", selected, "\n")
print(metrics, row.names = FALSE)
cat("Default illustrative scenario (NOT a forecast):\n")
print(data.frame(
  selected_games = totals$games,
  simulated_unsold_seats = totals$unsold,
  additional_synthetic_tickets = totals$extra,
  hypothetical_gross_revenue_usd = totals$gross_revenue_usd,
  hypothetical_marketing_cost_usd = totals$marketing_spend_usd,
  hypothetical_new_sellthrough = totals$scenario_sellthrough
), row.names = FALSE)
cat("Next: shiny::runApp()\n")
