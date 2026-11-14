# STAGE 3: Strict referential integrity, seat inventory and revenue audit.
# source("scripts/05_validate_synthetic_ticketing.R")
source("R/synthetic_helpers.R")
syn_dir <- "data/synthetic"
namesets <- c("customers", "memberships", "seat_inventory", "ticket_orders", "ticket_order_lines")
paths <- file.path(syn_dir, paste0(namesets, "_draft.rds"))
if (!all(file.exists(paths))) stop("Missing draft files. Run script 04 first.")
sets <- setNames(lapply(paths, readRDS), namesets)
customers <- sets$customers
memberships <- sets$memberships
inventory <- sets$seat_inventory
orders <- sets$ticket_orders
lines <- sets$ticket_order_lines
real <- readRDS("data/processed/games_real.rds")
ppg <- real[!is.na(real$is_ppg_home) & real$is_ppg_home, , drop = FALSE]

checks <- data.frame(check = character(), expected = character(), actual = character(),
                     passed = logical(), stringsAsFactors = FALSE)
add_check <- function(label, expected, actual, passed) {
  checks <<- rbind(checks, data.frame(check = label,
                                    expected = as.character(expected),
                                    actual = as.character(actual),
                                    passed = isTRUE(passed)))
}

# Basic keys and provenance --------------------------------------------------
add_check("122 real PPG home games", 122, nrow(ppg), nrow(ppg) == 122)
add_check("inventory rows", 122 * 4, nrow(inventory), nrow(inventory) == 122 * 4)
add_check("unique customer IDs", nrow(customers), length(unique(customers$customer_id)),
          !anyNA(customers$customer_id) && !anyDuplicated(customers$customer_id))
add_check("unique membership IDs", nrow(memberships), length(unique(memberships$membership_id)),
          !anyDuplicated(memberships$membership_id))
add_check("unique order IDs", nrow(orders), length(unique(orders$order_id)),
          !anyDuplicated(orders$order_id))
add_check("unique line IDs", nrow(lines), length(unique(lines$order_line_id)),
          !anyDuplicated(lines$order_line_id))
add_check("unique inventory game-category keys", nrow(inventory),
          length(unique(paste(inventory$game_id, inventory$seat_category))),
          !anyDuplicated(paste(inventory$game_id, inventory$seat_category)))
add_check("all Stage 3 records labeled SYNTHETIC", "TRUE",
          all(vapply(sets, function(df) all(df$data_origin == "SYNTHETIC"), logical(1))),
          all(vapply(sets, function(df) all(df$data_origin == "SYNTHETIC"), logical(1))))

add_check("order customers exist", 0, sum(!(orders$customer_id %in% customers$customer_id)),
          all(orders$customer_id %in% customers$customer_id))
add_check("member customers exist", 0, sum(!(memberships$customer_id %in% customers$customer_id)),
          all(memberships$customer_id %in% customers$customer_id))
add_check("line orders exist", 0, sum(!(lines$order_id %in% orders$order_id)),
          all(lines$order_id %in% orders$order_id))
add_check("line games exist at PPG", 0, sum(!(lines$game_id %in% ppg$game_id)),
          all(lines$game_id %in% ppg$game_id))
add_check("inventory games exist at PPG", 0, sum(!(inventory$game_id %in% ppg$game_id)),
          all(inventory$game_id %in% ppg$game_id))
add_check("valid seating categories", 0,
          sum(!(lines$seat_category %in% STAGE3_CATEGORIES)),
          all(lines$seat_category %in% STAGE3_CATEGORIES))

# Orders must belong to the same customer, season and channel as their lines.
order_idx <- match(lines$order_id, orders$order_id)
valid_order_index <- all(!is.na(order_idx))
consistent_lines <- valid_order_index && all(
  lines$customer_id == orders$customer_id[order_idx] &
  lines$season == orders$season[order_idx] &
  lines$order_channel == orders$order_channel[order_idx] &
  lines$order_date == orders$order_date[order_idx]
)
add_check("line and order header fields agree", "TRUE", consistent_lines, consistent_lines)

# Game date controls ---------------------------------------------------------
game_idx <- match(lines$game_id, ppg$game_id)
valid_game_index <- all(!is.na(game_idx))
game_date_ok <- valid_game_index && all(lines$order_date <= as.Date(ppg$game_date[game_idx]))
add_check("all purchases on or before games", "TRUE", game_date_ok, game_date_ok)
customer_idx <- match(lines$customer_id, customers$customer_id)
signup_ok <- all(!is.na(customer_idx)) && all(
  lines$order_date >= customers$signup_date[customer_idx]
)
add_check("no order before customer CRM entry", "TRUE", signup_ok, signup_ok)
add_check("season matches game", "TRUE",
          valid_game_index && all(lines$season == ppg$season[game_idx]),
          valid_game_index && all(lines$season == ppg$season[game_idx]))

# Membership relationships ---------------------------------------------------
member_lines <- lines[lines$order_channel == "SEASON_MEMBERSHIP", , drop = FALSE]
other_lines <- lines[lines$order_channel != "SEASON_MEMBERSHIP", , drop = FALSE]
member_ids_valid <- all(member_lines$membership_id %in% memberships$membership_id)
add_check("membership line references valid", "TRUE", member_ids_valid, member_ids_valid)
add_check("nonmember lines have no membership ID", "TRUE",
          all(is.na(other_lines$membership_id)), all(is.na(other_lines$membership_id)))
add_check("one membership per customer-season", "TRUE",
          !anyDuplicated(paste(memberships$customer_id, memberships$season)),
          !anyDuplicated(paste(memberships$customer_id, memberships$season)))
member_idx <- match(member_lines$membership_id, memberships$membership_id)
member_details_ok <- all(!is.na(member_idx)) && all(
  member_lines$customer_id == memberships$customer_id[member_idx] &
  member_lines$season == memberships$season[member_idx] &
  member_lines$seat_category == memberships$seat_category[member_idx] &
  member_lines$quantity == memberships$seats_per_game[member_idx] &
  member_lines$paid_unit_price_cents == memberships$paid_unit_price_cents[member_idx] &
  member_lines$order_id == memberships$order_id[member_idx]
)
add_check("membership entitlements match contracts", "TRUE",
          member_details_ok, member_details_ok)
add_check("unique membership-game rights", "TRUE",
          !anyDuplicated(paste(member_lines$membership_id, member_lines$game_id)),
          !anyDuplicated(paste(member_lines$membership_id, member_lines$game_id)))
member_counts <- table(member_lines$membership_id)
rights_ok <- all(as.integer(member_counts[memberships$membership_id]) ==
                 memberships$eligible_games)
add_check("every membership covers every PPG game", "TRUE", rights_ok, rights_ok)

# Current-season renewals must be members in the immediately previous season.
renewal_ok <- TRUE
for (si in seq_along(STAGE3_SEASONS)) {
  current <- memberships[memberships$season == STAGE3_SEASONS[si], , drop = FALSE]
  previous_ids <- if (si == 1L) character(0) else
    memberships$customer_id[memberships$season == STAGE3_SEASONS[si - 1L]]
  renewal_ok <- renewal_ok && all(current$is_renewal ==
                                 (current$customer_id %in% previous_ids))
}
add_check("renewal flags match prior-season membership", "TRUE", renewal_ok, renewal_ok)

# Per-seat prices, paid quantities, amounts ---------------------------------
line_math <- all(
  lines$quantity > 0 & lines$list_unit_price_cents > 0 &
  lines$paid_unit_price_cents > 0 &
  lines$paid_unit_price_cents <= lines$list_unit_price_cents &
  lines$gross_revenue_cents == lines$quantity * lines$list_unit_price_cents &
  lines$net_revenue_cents == lines$quantity * lines$paid_unit_price_cents &
  lines$discount_cents == lines$gross_revenue_cents - lines$net_revenue_cents
)
add_check("prices and discounts reconcile in cents", "TRUE", line_math, line_math)
add_check("all order totals positive", "TRUE",
          all(orders$order_total_cents > 0), all(orders$order_total_cents > 0))

member_revenue <- aggregate(net_revenue_cents ~ membership_id, member_lines, sum)
member_sum <- member_revenue$net_revenue_cents[
  match(memberships$membership_id, member_revenue$membership_id)
]
member_money_ok <- all(!is.na(member_sum)) && all(
  member_sum == memberships$contract_value_cents
)
add_check("one upfront membership payment equals all game rights", "TRUE",
          member_money_ok, member_money_ok)

other_order_idx <- match(other_lines$order_id, orders$order_id)
other_money_ok <- all(!is.na(other_order_idx)) && all(
  other_lines$net_revenue_cents == orders$order_total_cents[other_order_idx]
)
add_check("single-game and group order totals reconcile", "TRUE",
          other_money_ok, other_money_ok)
add_check("no duplicate nonmember order lines", "TRUE",
          !anyDuplicated(other_lines$order_id), !anyDuplicated(other_lines$order_id))
revenue_match <- sum(orders$order_total_cents) == sum(lines$net_revenue_cents)
add_check("all-orders cash equals allocated game revenue", "TRUE",
          revenue_match, revenue_match)

# Capacity / inventory reconciliation ---------------------------------------
inv_capacity <- aggregate(capacity_seats ~ game_id, inventory, sum)
capacity_ok <- nrow(inv_capacity) == 122L && all(inv_capacity$capacity_seats == 18187L)
add_check("synthetic arena capacity equals reference per game", "TRUE",
          capacity_ok, capacity_ok)
inv_rows_ok <- all(inventory$held_seats >= 0 &
                   inventory$membership_seats >= 0 &
                   inventory$sellable_seats == inventory$capacity_seats - inventory$held_seats &
                   inventory$target_paid_tickets <= inventory$sellable_seats &
                   inventory$membership_seats <= inventory$sellable_seats)
add_check("inventory holds and targets valid", "TRUE", inv_rows_ok, inv_rows_ok)

sold <- aggregate(quantity ~ game_id + seat_category, lines, sum)
keys <- paste(inventory$game_id, inventory$seat_category)
sold_idx <- match(keys, paste(sold$game_id, sold$seat_category))
sold_qty <- sold$quantity[sold_idx]
sold_qty[is.na(sold_qty)] <- 0L
sold_ok <- all(sold_qty <= inventory$sellable_seats) &&
  all(sold_qty == inventory$target_paid_tickets)
add_check("ticket sales exactly match targets without overselling", "TRUE",
          sold_ok, sold_ok)

member_sold <- aggregate(quantity ~ game_id + seat_category, member_lines, sum)
member_idx_by_inv <- match(keys, paste(member_sold$game_id, member_sold$seat_category))
member_qty <- member_sold$quantity[member_idx_by_inv]
member_qty[is.na(member_qty)] <- 0L
member_inv_ok <- all(member_qty == inventory$membership_seats)
add_check("membership seats match reserved inventory", "TRUE", member_inv_ok, member_inv_ok)

# Write audit before accepting data -----------------------------------------
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)
write.csv(checks, "outputs/tables/stage3_data_quality_checks.csv", row.names = FALSE)
print(checks, row.names = FALSE)
if (!all(checks$passed)) {
  stop("Stage 3 validation failed. Inspect outputs/tables/stage3_data_quality_checks.csv")
}

# Publish final synthetic RDS files only after every check passes.
for (nm in names(sets)) {
  saveRDS(sets[[nm]], file.path(syn_dir, paste0(nm, ".rds")), compress = "gzip")
}

# Game-level summary deliberately labels observed vs simulated measurements.
game_sales <- aggregate(lines[c("quantity", "net_revenue_cents")],
                        by = list(game_id = lines$game_id), FUN = sum)
names(game_sales)[2:3] <- c("sim_paid_tickets", "sim_ticket_revenue_cents")
game_inventory <- aggregate(inventory[c("sellable_seats", "capacity_seats")],
                            by = list(game_id = inventory$game_id), FUN = sum)
summary <- merge(ppg[, c("game_id", "season", "game_date", "opponent",
                         "reported_attendance")], game_sales,
                 by = "game_id", sort = FALSE)
summary <- merge(summary, game_inventory, by = "game_id", sort = FALSE)
summary <- summary[order(summary$game_date), , drop = FALSE]
summary$sim_sellthrough <- summary$sim_paid_tickets / summary$sellable_seats
summary$sim_revenue_per_paid_ticket <-
  summary$sim_ticket_revenue_cents / 100 / summary$sim_paid_tickets
summary$real_attendance_origin <- "OFFICIAL_NHL_GAME_SUMMARY"
summary$financial_data_origin <- "SYNTHETIC"
saveRDS(summary, file.path(syn_dir, "game_business_summary.rds"))
write.csv(summary, "outputs/tables/stage3_game_business_summary.csv", row.names = FALSE)

renewal <- do.call(rbind, lapply(2:length(STAGE3_SEASONS), function(i) {
  prior <- memberships$customer_id[memberships$season == STAGE3_SEASONS[i - 1L]]
  current <- memberships$customer_id[memberships$season == STAGE3_SEASONS[i]]
  data.frame(season = STAGE3_SEASONS[i], eligible_prior_members = length(prior),
             renewed_members = sum(prior %in% current),
             sim_renewal_rate = mean(prior %in% current),
             data_origin = "SYNTHETIC")
}))
write.csv(renewal, "outputs/tables/stage3_membership_renewal.csv", row.names = FALSE)
message("Synthetic membership renewal summary:")
print(renewal, row.names = FALSE)

customer_returning <- do.call(rbind, lapply(STAGE3_SEASONS, function(s) {
  now <- unique(orders$customer_id[orders$season == s])
  prior <- unique(orders$customer_id[orders$season < s])
  data.frame(season = s, active_customers = length(now),
             returning_customers = sum(now %in% prior),
             first_observed_customers = sum(!(now %in% prior)),
             sim_returning_rate = mean(now %in% prior),
             data_origin = "SYNTHETIC")
}))
write.csv(customer_returning, "outputs/tables/stage3_customer_returning.csv",
          row.names = FALSE)
message("Synthetic new versus returning buyers:")
print(customer_returning, row.names = FALSE)

message("PASS: All ", nrow(checks), " Stage 3 checks passed.")
message("Final synthetic datasets published to ", syn_dir)
message("Next: source('scripts/06_preview_synthetic_kpis.R')")
