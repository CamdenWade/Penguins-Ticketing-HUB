# STAGE 4B — Run before launching Shiny after copying new files.
# source("scripts/09_check_customer_inputs.R")
# No source data are modified; only audit CSVs are written.

packages <- c("shiny", "bslib", "dplyr", "ggplot2", "scales", "DT")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Missing packages: ", paste(missing, collapse = ", "),
                          ". Run script 07 first.", call. = FALSE)

source("R/shiny_helpers.R")
source("R/shiny_data.R")
source("R/shiny_customer_data.R")

stage4a <- load_stage4a_data()
stage4b <- load_stage4b_data(stage4a)
checks <- data.frame(check = character(), expected = character(), actual = character(),
                     passed = logical(), stringsAsFactors = FALSE)
check <- function(label, expected, actual, pass) {
  checks <<- rbind(checks,
                   data.frame(check = label, expected = as.character(expected),
                              actual = as.character(actual), passed = isTRUE(pass)))
}
counts <- stage4b$original_counts
cohorts <- stage4b$cohorts
accounts <- stage4b$game_accounts
order_summary <- stage4b$account_season

check("Real PPG games", 122, nrow(stage4a$real), nrow(stage4a$real) == 122L)
check("Synthetic game summaries", 122, nrow(stage4a$business), nrow(stage4a$business) == 122L)
check("Synthetic customers", 35000, counts[["customers"]], counts[["customers"]] == 35000L)
check("Membership contracts", 7458, counts[["memberships"]], counts[["memberships"]] == 7458L)
check("Order headers", 432205, counts[["orders"]], counts[["orders"]] == 432205L)
check("Order lines", 727847, counts[["order_lines"]], counts[["order_lines"]] == 727847L)
check("Three full-season cohorts", 3, nrow(cohorts), nrow(cohorts) == 3L)
check("First season retention unavailable", "NA", cohorts$purchaser_retention[1],
      is.na(cohorts$purchaser_retention[1]))
check("First season renewal unavailable", "NA", cohorts$member_renewal[1],
      is.na(cohorts$member_renewal[1]))
check("Later cohort renewal rates valid", "[0,1]", paste(round(cohorts$member_renewal[-1], 3), collapse = ","),
      all(is.finite(cohorts$member_renewal[-1])) &&
        all(cohorts$member_renewal[-1] >= 0 & cohorts$member_renewal[-1] <= 1))
check("Later purchaser retention rates valid", "[0,1]", paste(round(cohorts$purchaser_retention[-1], 3), collapse = ","),
      all(is.finite(cohorts$purchaser_retention[-1])) &&
        all(cohorts$purchaser_retention[-1] >= 0 & cohorts$purchaser_retention[-1] <= 1))
check("Customer cohort counts reconcile", "TRUE", all(cohorts$active_accounts ==
      cohorts$first_observed + cohorts$retained_from_prior + cohorts$reactivated),
      all(cohorts$active_accounts ==
      cohorts$first_observed + cohorts$retained_from_prior + cohorts$reactivated))
check("No duplicate customer-game keys", 0,
      anyDuplicated(paste(accounts$game_id, accounts$customer_id)),
      !anyDuplicated(paste(accounts$game_id, accounts$customer_id)))
check("No duplicate customer-season keys", 0,
      anyDuplicated(paste(order_summary$season, order_summary$customer_id)),
      !anyDuplicated(paste(order_summary$season, order_summary$customer_id)))
check("All customer-game records at PPG", "TRUE",
      all(accounts$game_id %in% stage4a$real$game_id),
      all(accounts$game_id %in% stage4a$real$game_id))
check("Customer paid tickets equal sales total",
      sum(as.double(stage4a$business$sim_paid_tickets)), sum(accounts$paid_tickets),
      sum(accounts$paid_tickets) == sum(as.double(stage4a$business$sim_paid_tickets)))
check("Customer revenue cents equals sales total",
      sum(as.double(stage4a$business$sim_ticket_revenue_cents)),
      sum(accounts$earned_revenue_cents),
      sum(accounts$earned_revenue_cents) == sum(as.double(stage4a$business$sim_ticket_revenue_cents)))
check("Customer data provenance", "SYNTHETIC", stage4b$data_origin,
      identical(stage4b$data_origin, "SYNTHETIC"))
check("Each annual cohort has active customers", "TRUE",
      all(cohorts$active_accounts > 0), all(cohorts$active_accounts > 0))

# Full-selection segment breakdown must reconcile to game totals.
segments <- accounts |>
  dplyr::group_by(.data$fan_segment) |>
  dplyr::summarise(
    customers = dplyr::n_distinct(.data$customer_id),
    paid_tickets = sum(.data$paid_tickets),
    revenue_cents = sum(.data$earned_revenue_cents),
    .groups = "drop"
  ) |>
  dplyr::mutate(revenue_usd = .data$revenue_cents / 100) |>
  dplyr::arrange(dplyr::desc(.data$revenue_cents))
check("Segment revenue reconciles", "TRUE",
      sum(segments$revenue_cents) == sum(stage4a$business$sim_ticket_revenue_cents),
      sum(segments$revenue_cents) == sum(stage4a$business$sim_ticket_revenue_cents))

dir.create("outputs/tables", showWarnings = FALSE, recursive = TRUE)
utils::write.csv(checks, "outputs/tables/stage4b_data_quality_checks.csv", row.names = FALSE)
utils::write.csv(cohorts, "outputs/tables/stage4b_customer_cohorts.csv", row.names = FALSE)
segments$data_origin <- "SYNTHETIC"
utils::write.csv(segments, "outputs/tables/stage4b_customer_segments.csv", row.names = FALSE)

print(checks, row.names = FALSE)
if (anyNA(checks$passed) || !all(checks$passed)) {
  stop("Stage 4B preflight FAILED. Review outputs/tables/stage4b_data_quality_checks.csv",
       call. = FALSE)
}
message("PASS — Stage 4B preflight: ", nrow(checks), "/", nrow(checks), " checks passed.")
message("Synthetic customers: ", format(counts[["customers"]], big.mark = ","))
message("Customer-game aggregate rows: ", format(nrow(accounts), big.mark = ","))
message("Full-season synthetic membership and purchaser cohorts:")
print(cohorts[, c("season", "active_accounts", "member_renewal", "purchaser_retention")],
      row.names = FALSE)
message("Next: shiny::runApp()")
