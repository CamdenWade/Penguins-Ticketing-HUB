# STAGE 4B — Synthetic customer and membership aggregates.
# Loads the validated Stage 3 files once at startup. Does NOT modify RDS files.
# Requires source("R/shiny_helpers.R") and source("R/shiny_data.R") first.

load_stage4b_data <- function(stage4a) {
  paths <- c(
    customers = "data/synthetic/customers.rds",
    memberships = "data/synthetic/memberships.rds",
    orders = "data/synthetic/ticket_orders.rds",
    lines = "data/synthetic/ticket_order_lines.rds"
  )
  if (any(!file.exists(paths))) {
    stop("Stage 4B source files are missing: ",
         paste(unname(paths[!file.exists(paths)]), collapse = ", "),
         call. = FALSE)
  }
  customers <- readRDS(paths[["customers"]])
  memberships <- readRDS(paths[["memberships"]])
  orders <- readRDS(paths[["orders"]])
  lines <- readRDS(paths[["lines"]])

  requirements <- list(
    customers = c("customer_id", "crm_entry_season", "fan_segment", "data_origin"),
    memberships = c("membership_id", "order_id", "customer_id", "season",
                    "is_renewal", "contract_value_cents", "data_origin"),
    orders = c("order_id", "customer_id", "season", "order_channel",
               "order_total_cents", "data_origin"),
    lines = c("order_line_id", "game_id", "customer_id", "season", "order_id",
              "quantity", "net_revenue_cents", "data_origin")
  )
  inputs <- list(customers = customers, memberships = memberships,
                 orders = orders, lines = lines)
  for (nm in names(requirements)) {
    absent <- setdiff(requirements[[nm]], names(inputs[[nm]]))
    if (length(absent)) stop(nm, " missing: ", paste(absent, collapse = ", "), call. = FALSE)
    if (anyNA(inputs[[nm]]$data_origin) ||
        !all(inputs[[nm]]$data_origin == "SYNTHETIC")) {
      stop("Source must be synthetic: ", nm, call. = FALSE)
    }
  }
  if (nrow(customers) != 35000L || nrow(memberships) != 7458L ||
      nrow(orders) != 432205L || nrow(lines) != 727847L) {
    stop("Stage 3 row counts have changed. Re-run Stage 3 validation before using Stage 4B.",
         call. = FALSE)
  }
  if (anyDuplicated(customers$customer_id) || anyDuplicated(orders$order_id) ||
      anyDuplicated(memberships$membership_id) || anyDuplicated(lines$order_line_id) ||
      anyNA(customers$customer_id) || anyNA(orders$customer_id)) {
    stop("Stage 4B found missing or duplicate primary keys.", call. = FALSE)
  }
  if (!all(orders$customer_id %in% customers$customer_id) ||
      !all(lines$customer_id %in% customers$customer_id) ||
      !all(lines$order_id %in% orders$order_id) ||
      !all(memberships$customer_id %in% customers$customer_id) ||
      !all(lines$game_id %in% stage4a$real$game_id)) {
    stop("Stage 4B source foreign-key validation failed.", call. = FALSE)
  }
  if (!setequal(unique(orders$season), SEASON_ORDER) ||
      !setequal(unique(memberships$season), SEASON_ORDER) ||
      !setequal(unique(lines$season), SEASON_ORDER)) {
    stop("Unexpected customer data season(s).", call. = FALSE)
  }
  if (anyNA(orders$order_total_cents) || anyNA(lines$net_revenue_cents) ||
      any(lines$quantity <= 0) ||
      sum(as.double(orders$order_total_cents)) !=
        sum(as.double(lines$net_revenue_cents))) {
    stop("Stage 4B order/line financial reconciliation failed.", call. = FALSE)
  }

  # One record per customer x game. Membership game rights appear in this
  # view, but this is not a count of DISTINCT purchase transactions.
  game_accounts <- lines |>
    dplyr::group_by(.data$game_id, .data$customer_id) |>
    dplyr::summarise(
      paid_tickets = sum(as.double(.data$quantity)),
      earned_revenue_cents = sum(as.double(.data$net_revenue_cents)),
      .groups = "drop"
    )
  game_accounts$fan_segment <- customers$fan_segment[
    match(game_accounts$customer_id, customers$customer_id)
  ]
  if (anyNA(game_accounts$fan_segment)) stop("Missing customer segment mapping.")

  # The order header exists ONCE per purchase / membership contract;
  # aggregate from order HEADERS, not each game's membership rights.
  account_season <- orders |>
    dplyr::group_by(.data$season, .data$customer_id) |>
    dplyr::summarise(
      distinct_orders = dplyr::n(),
      cash_paid_cents = sum(as.double(.data$order_total_cents)),
      .groups = "drop"
    )
  account_season$fan_segment <- customers$fan_segment[
    match(account_season$customer_id, customers$customer_id)
  ]

  # Full-season observed-cohort histories. Season 1 is a baseline, not a
  # valid historical retention/renewal percentage.
  cohort_rows <- vector("list", length(SEASON_ORDER))
  for (i in seq_along(SEASON_ORDER)) {
    season <- SEASON_ORDER[i]
    current <- unique(account_season$customer_id[account_season$season == season])
    prev <- if (i == 1L) character() else unique(
      account_season$customer_id[account_season$season == SEASON_ORDER[i - 1L]]
    )
    ever_prior <- if (i == 1L) character() else unique(
      account_season$customer_id[account_season$season %in% SEASON_ORDER[seq_len(i - 1L)]]
    )
    prior_members <- if (i == 1L) character() else unique(
      memberships$customer_id[memberships$season == SEASON_ORDER[i - 1L]]
    )
    present_members <- unique(memberships$customer_id[memberships$season == season])
    cohort_rows[[i]] <- data.frame(
      season = season,
      active_accounts = length(current),
      first_observed = sum(!(current %in% ever_prior)),
      retained_from_prior = sum(current %in% prev),
      reactivated = sum(current %in% ever_prior & !(current %in% prev)),
      retention_eligible = if (i == 1L) NA_integer_ else length(prev),
      retained_accounts = if (i == 1L) NA_integer_ else sum(prev %in% current),
      membership_eligible = if (i == 1L) NA_integer_ else length(prior_members),
      renewed_members = if (i == 1L) NA_integer_ else sum(prior_members %in% present_members),
      current_members = length(present_members),
      data_origin = "SYNTHETIC",
      stringsAsFactors = FALSE
    )
  }
  cohorts <- dplyr::bind_rows(cohort_rows) |>
    dplyr::mutate(
      purchaser_retention = .data$retained_accounts / .data$retention_eligible,
      member_renewal = .data$renewed_members / .data$membership_eligible
    )

  if (!all(cohorts$active_accounts ==
           cohorts$first_observed + cohorts$retained_from_prior + cohorts$reactivated)) {
    stop("Customer cohort status totals do not reconcile.", call. = FALSE)
  }
  # Renewal counts must match the original Stage 3 is_renewal flags.
  renewals_from_contracts <- vapply(SEASON_ORDER, function(s) {
    sum(memberships$is_renewal[memberships$season == s])
  }, numeric(1))
  if (renewals_from_contracts[1] != 0 ||
      !all(renewals_from_contracts[-1] == cohorts$renewed_members[-1])) {
    stop("Membership renewal cohort does not match Stage 3 flags.", call. = FALSE)
  }

  # Prevent double-counting game-level sales when calculating customer revenue.
  game_totals <- game_accounts |>
    dplyr::group_by(.data$game_id) |>
    dplyr::summarise(tickets = sum(.data$paid_tickets),
                     cents = sum(.data$earned_revenue_cents), .groups = "drop")
  idx <- match(stage4a$business$game_id, game_totals$game_id)
  if (anyNA(idx) ||
      !all(as.double(stage4a$business$sim_paid_tickets) == game_totals$tickets[idx]) ||
      !all(as.double(stage4a$business$sim_ticket_revenue_cents) == game_totals$cents[idx])) {
    stop("Customer activity is inconsistent with Stage 4A sales summaries.", call. = FALSE)
  }

  # Free the large raw tables: Shiny filters smaller, derived tables only.
  rm(lines, orders, memberships, customers, inputs)
  gc(verbose = FALSE)
  list(
    game_accounts = game_accounts,
    account_season = account_season,
    cohorts = cohorts,
    original_counts = c(customers = 35000L, memberships = 7458L,
                        orders = 432205L, order_lines = 727847L),
    data_origin = "SYNTHETIC"
  )
}
