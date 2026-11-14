# STAGE 5B — Pure synthetic revenue scenario calculations.
# All inventory, ticket sales, and revenues are from the Stage 3 simulation.
# This is a hypothetical WHAT-IF calculator, not a forecast of demand.
# Prices and costs are input assumptions. Currency arithmetic uses cents.

calculate_ticket_opportunity <- function(business,
                                         capture_pct = 15,
                                         incremental_price_usd = 90,
                                         acquisition_cost_usd = 10) {
  necessary <- c("game_id", "season", "game_date", "opponent",
                 "sim_paid_tickets", "sim_ticket_revenue_cents", "sellable_seats")
  absent <- setdiff(necessary, names(business))
  if (length(absent)) {
    stop("Business summary missing: ", paste(absent, collapse = ", "), call. = FALSE)
  }
  choices <- c(capture_pct, incremental_price_usd, acquisition_cost_usd)
  if (length(choices) != 3L || anyNA(choices) || any(!is.finite(choices)) ||
      capture_pct < 0 || capture_pct > 100 || incremental_price_usd < 0 ||
      acquisition_cost_usd < 0) {
    stop("Scenario inputs must be finite; capture 0–100%, price/cost nonnegative.",
         call. = FALSE)
  }
  if (anyNA(business[, necessary, drop = FALSE]) ||
      anyDuplicated(as.character(business$game_id)) ||
      any(!is.finite(business$sim_paid_tickets)) ||
      any(!is.finite(business$sim_ticket_revenue_cents)) ||
      any(!is.finite(business$sellable_seats)) ||
      any(business$sim_paid_tickets < 0) ||
      any(business$sim_ticket_revenue_cents < 0) ||
      any(business$sellable_seats <= 0) ||
      any(business$sim_paid_tickets > business$sellable_seats) ||
      any(abs(business$sim_paid_tickets - round(business$sim_paid_tickets)) > 1e-8)) {
    stop("Invalid or inconsistent synthetic ticket inventory/sales records.", call. = FALSE)
  }
  # Fraction of currently UNsold inventory converted to extra paid tickets.
  # Floor is applied separately to each game to avoid fractional ticket sales.
  unsold <- as.integer(round(business$sellable_seats - business$sim_paid_tickets))
  added <- as.integer(floor(unsold * capture_pct / 100 + 1e-10))
  price_cents <- as.numeric(round(incremental_price_usd * 100))
  cost_cents <- as.numeric(round(acquisition_cost_usd * 100))
  if (price_cents > 1e8 || cost_cents > 1e8) {
    stop("Scenario amounts exceed supported bounds.", call. = FALSE)
  }

  data.frame(
    game_id = as.character(business$game_id),
    season = as.character(business$season),
    game_date = as.Date(business$game_date),
    opponent = as.character(business$opponent),
    sim_sellable_seats = as.integer(round(business$sellable_seats)),
    sim_paid_tickets = as.integer(round(business$sim_paid_tickets)),
    sim_unsold_seats = unsold,
    scenario_capture_pct = rep(capture_pct, nrow(business)),
    scenario_extra_tickets = added,
    scenario_price_cents = rep(price_cents, nrow(business)),
    scenario_acquisition_cost_per_ticket_cents = rep(cost_cents, nrow(business)),
    scenario_added_revenue_cents = as.numeric(added) * price_cents,
    scenario_marketing_spend_cents = as.numeric(added) * cost_cents,
    scenario_revenue_less_assumed_marketing_cents =
      as.numeric(added) * (price_cents - cost_cents),
    scenario_total_paid_tickets = as.integer(round(business$sim_paid_tickets)) + added,
    scenario_sellthrough = (as.numeric(business$sim_paid_tickets) + added) /
      as.numeric(business$sellable_seats),
    sim_existing_revenue_cents = as.numeric(business$sim_ticket_revenue_cents),
    scenario_total_revenue_cents = as.numeric(business$sim_ticket_revenue_cents) +
      as.numeric(added) * price_cents,
    financial_data_origin = rep("SYNTHETIC", nrow(business)),
    scenario_origin = rep("USER_ASSUMPTIONS_NOT_A_FORECAST", nrow(business)),
    stringsAsFactors = FALSE
  )
}

summarize_ticket_opportunity <- function(scenario) {
  if (!nrow(scenario)) {
    return(list(games = 0L, unsold = 0, extra = 0, current_tickets = 0,
                sellable = 0, gross_revenue_usd = 0, marketing_spend_usd = 0,
                contribution_after_assumed_marketing_usd = 0,
                existing_revenue_usd = 0, total_revenue_usd = 0,
                current_sellthrough = NA_real_, scenario_sellthrough = NA_real_))
  }
  s <- function(column) sum(as.double(scenario[[column]]))
  sellable <- s("sim_sellable_seats")
  current <- s("sim_paid_tickets")
  extra <- s("scenario_extra_tickets")
  list(
    games = nrow(scenario),
    unsold = s("sim_unsold_seats"),
    extra = extra,
    current_tickets = current,
    sellable = sellable,
    gross_revenue_usd = s("scenario_added_revenue_cents") / 100,
    marketing_spend_usd = s("scenario_marketing_spend_cents") / 100,
    contribution_after_assumed_marketing_usd =
      s("scenario_revenue_less_assumed_marketing_cents") / 100,
    existing_revenue_usd = s("sim_existing_revenue_cents") / 100,
    total_revenue_usd = s("scenario_total_revenue_cents") / 100,
    current_sellthrough = current / sellable,
    scenario_sellthrough = (current + extra) / sellable
  )
}
