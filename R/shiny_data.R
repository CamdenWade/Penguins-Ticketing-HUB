# STAGE 4A — Load validated Stage 2 + Stage 3 files and prepare in-memory
# aggregates. This file does not modify any of the source RDS files.

load_stage4a_data <- function() {
  inputs <- c(
    real = "data/processed/games_real.rds",
    business = "data/synthetic/game_business_summary.rds",
    inventory = "data/synthetic/seat_inventory.rds",
    lines = "data/synthetic/ticket_order_lines.rds"
  )
  missing <- unname(inputs[!file.exists(inputs)])
  if (length(missing)) {
    stop("Stage 4A requires validated Stage 2 and 3 files. Missing:\n - ",
         paste(missing, collapse = "\n - "), call. = FALSE)
  }

  # Previously generated acceptance audits are checked again if available.
  for (audit_file in c("outputs/tables/data_quality_checks.csv",
                       "outputs/tables/stage3_data_quality_checks.csv")) {
    if (file.exists(audit_file)) {
      audit <- utils::read.csv(audit_file, stringsAsFactors = FALSE)
      if (!"passed" %in% names(audit) || !nrow(audit) ||
          anyNA(audit$passed) || !all(audit$passed)) {
        stop("Cannot launch app: quality audit failed: ", audit_file, call. = FALSE)
      }
    }
  }

  real <- readRDS(inputs[["real"]])
  business <- readRDS(inputs[["business"]])
  inventory <- readRDS(inputs[["inventory"]])
  lines <- readRDS(inputs[["lines"]])

  required <- list(
    real = c("game_id", "game_date", "season", "opponent", "venue",
             "is_ppg_home", "reported_attendance", "nominal_capacity",
             "nominal_utilization", "result", "is_weekend", "day_of_week"),
    business = c("game_id", "game_date", "season", "opponent",
                 "reported_attendance", "sim_paid_tickets",
                 "sim_ticket_revenue_cents", "sellable_seats", "capacity_seats",
                 "sim_sellthrough", "sim_revenue_per_paid_ticket",
                 "real_attendance_origin", "financial_data_origin"),
    inventory = c("game_id", "seat_category", "sellable_seats", "capacity_seats",
                  "data_origin"),
    lines = c("game_id", "seat_category", "order_channel", "quantity",
              "net_revenue_cents", "data_origin")
  )
  tables <- list(real = real, business = business, inventory = inventory, lines = lines)
  for (nm in names(required)) {
    absent <- setdiff(required[[nm]], names(tables[[nm]]))
    if (length(absent)) {
      stop(nm, " is missing columns: ", paste(absent, collapse = ", "), call. = FALSE)
    }
  }

  ppg <- real[!is.na(real$is_ppg_home) & real$is_ppg_home, , drop = FALSE]
  if (nrow(real) != 123L || nrow(ppg) != 122L || nrow(business) != 122L ||
      anyDuplicated(ppg$game_id) || anyDuplicated(business$game_id) ||
      !setequal(as.character(ppg$game_id), as.character(business$game_id))) {
    stop("Unexpected Stage 2 / Stage 3 game counts or game IDs.", call. = FALSE)
  }
  if (anyNA(ppg$reported_attendance) || any(ppg$reported_attendance <= 0) ||
      !all(business$real_attendance_origin == "OFFICIAL_NHL_GAME_SUMMARY") ||
      !all(business$financial_data_origin == "SYNTHETIC") ||
      !all(inventory$data_origin == "SYNTHETIC") ||
      !all(lines$data_origin == "SYNTHETIC")) {
    stop("A source table failed a Stage 4A data/provenance check.", call. = FALSE)
  }

  index <- match(business$game_id, ppg$game_id)
  if (!all(as.character(business$season) == as.character(ppg$season[index])) ||
      !all(as.Date(business$game_date) == as.Date(ppg$game_date[index])) ||
      !all(as.character(business$opponent) == as.character(ppg$opponent[index])) ||
      !all(business$reported_attendance == ppg$reported_attendance[index])) {
    stop("Real-game fields differ between Stage 2 and Stage 3 summaries.", call. = FALSE)
  }
  if (nrow(inventory) != 488L ||
      anyDuplicated(paste(inventory$game_id, inventory$seat_category)) ||
      !all(inventory$game_id %in% ppg$game_id) ||
      !all(lines$game_id %in% ppg$game_id)) {
    stop("Stage 3 inventory or lines do not match the 122 PPG games.", call. = FALSE)
  }

  # Build responsive dashboard aggregates ONCE (no 727k-row calculation per filter).
  category <- lines |>
    dplyr::group_by(.data$game_id, .data$seat_category) |>
    dplyr::summarise(
      sim_paid_tickets = sum(as.double(.data$quantity)),
      sim_revenue_cents = sum(as.double(.data$net_revenue_cents)),
      .groups = "drop"
    ) |>
    dplyr::left_join(
      inventory |>
        dplyr::select(.data$game_id, .data$seat_category,
                      .data$sellable_seats, .data$capacity_seats),
      by = c("game_id", "seat_category")
    )

  channel <- lines |>
    dplyr::group_by(.data$game_id, .data$order_channel) |>
    dplyr::summarise(
      sim_paid_tickets = sum(as.double(.data$quantity)),
      sim_revenue_cents = sum(as.double(.data$net_revenue_cents)),
      .groups = "drop"
    )

  reconciled <- category |>
    dplyr::group_by(.data$game_id) |>
    dplyr::summarise(
      sim_paid_tickets = sum(.data$sim_paid_tickets),
      sim_revenue_cents = sum(.data$sim_revenue_cents),
      sellable_seats = sum(.data$sellable_seats),
      .groups = "drop"
    )
  ridx <- match(business$game_id, reconciled$game_id)
  if (anyNA(ridx) || anyNA(category$sellable_seats) ||
      !all(business$sim_paid_tickets == reconciled$sim_paid_tickets[ridx]) ||
      !all(as.double(business$sim_ticket_revenue_cents) == reconciled$sim_revenue_cents[ridx]) ||
      !all(business$sellable_seats == reconciled$sellable_seats[ridx])) {
    stop("Stage 4A revenue/volume/inventory reconciliation failed.", call. = FALSE)
  }

  # Do not retain the large ticket-line data frame once the aggregations exist.
  rm(lines, inventory, tables, real)
  gc(verbose = FALSE)
  list(
    real = ppg[order(ppg$game_date, ppg$game_id), , drop = FALSE],
    business = business[order(business$game_date, business$game_id), , drop = FALSE],
    category = category,
    channel = channel
  )
}
