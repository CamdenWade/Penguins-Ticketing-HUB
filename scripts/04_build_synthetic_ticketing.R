# STAGE 3: Reproducible simulated ticket, customer, membership, and order data.
# Run from the RStudio project root, after validated Stage 2 is finished.
# source("scripts/04_build_synthetic_ticketing.R")

source("R/synthetic_helpers.R")
set.seed(STAGE3_SEED)

real_path <- "data/processed/games_real.rds"
if (!file.exists(real_path)) stop("Run and validate Stage 2 first: missing ", real_path)
games_real <- readRDS(real_path)
required <- c("game_id", "season", "game_date", "reported_attendance", "is_ppg_home")
if (!all(required %in% names(games_real))) stop("Stage 2 data is missing required fields.")
if (anyNA(games_real$reported_attendance)) stop("Stage 2 has missing real attendance.")

ppg <- games_real[!is.na(games_real$is_ppg_home) & games_real$is_ppg_home, , drop = FALSE]
ppg <- ppg[order(ppg$game_date, ppg$game_id), , drop = FALSE]
if (nrow(ppg) != 122L || anyDuplicated(ppg$game_id) ||
    !identical(sort(unique(as.character(ppg$season))), STAGE3_SEASONS)) {
  stop("Unexpected PPG games: check your validated Stage 2 input before simulating.")
}
ppg$season <- as.character(ppg$season)
ppg$game_date <- as.Date(ppg$game_date)

out_dir <- "data/synthetic"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)

# 1) CUSTOMER FILE ----------------------------------------------------------
# Anonymous, synthetic customer IDs; no names, emails, or personal information.
cohort_sizes <- c(15000L, 10000L, 10000L)
customer_season <- rep(STAGE3_SEASONS, times = cohort_sizes)
n_customers <- length(customer_season)
segments <- c("Loyal Supporter", "Family & Group", "Value Seeker",
              "Occasional Fan", "Premium Buyer")
segment_prob <- c(0.23, 0.25, 0.25, 0.20, 0.07)
segment <- sample(segments, n_customers, TRUE, prob = segment_prob)
segment_weights <- c("Loyal Supporter" = 3.1, "Family & Group" = 2.2,
                     "Value Seeker" = 1.35, "Occasional Fan" = 0.55,
                     "Premium Buyer" = 2.8)

signup <- as.Date(unlist(lapply(STAGE3_SEASONS, function(s) {
  year <- season_start_year(s)
  possible <- seq(as.Date(sprintf("%s-05-01", year)),
                  as.Date(sprintf("%s-07-30", year)), by = "day")
  sample(possible, cohort_sizes[match(s, STAGE3_SEASONS)], replace = TRUE)
})), origin = "1970-01-01")

customers <- data.frame(
  customer_id = sprintf("CUS%06d", seq_len(n_customers)),
  crm_entry_season = customer_season,
  signup_date = signup,
  fan_segment = segment,
  purchase_weight = pmax(0.001, round(
    unname(segment_weights[segment]) * rgamma(n_customers, shape = 2.5, rate = 2.5),
    digits = 4
  )),
  data_origin = "SYNTHETIC",
  stringsAsFactors = FALSE
)
stopifnot(all(customers$purchase_weight > 0))

# 2) SEASON-TICKET MEMBERSHIP CONTRACTS -------------------------------------
# One order per contract per season. Rights to the home games are recognized
# later as game-level lines, NOT charged again as a second purchase.
member_weights <- c("Loyal Supporter" = 5.0, "Family & Group" = 2.0,
                    "Value Seeker" = 0.7, "Occasional Fan" = 0.25,
                    "Premium Buyer" = 3.2)
renewal_prob <- c("Loyal Supporter" = 0.89, "Family & Group" = 0.84,
                  "Value Seeker" = 0.77, "Occasional Fan" = 0.68,
                  "Premium Buyer" = 0.90)
new_member_targets <- c(2300L, 500L, 550L)
member_parts <- vector("list", length(STAGE3_SEASONS))
ever_member_ids <- character(0)
previous <- NULL

for (s_i in seq_along(STAGE3_SEASONS)) {
  season <- STAGE3_SEASONS[s_i]
  renewed <- if (is.null(previous)) {
    data.frame(
      customer_id = character(),
      seat_category = character(),
      seats_per_game = integer(),
      stringsAsFactors = FALSE
    )
  } else {
    p <- unname(renewal_prob[customers$fan_segment[
      match(previous$customer_id, customers$customer_id)
    ]])
    previous[runif(nrow(previous)) < p, , drop = FALSE]
  }

  eligible <- which(customers$crm_entry_season <= season &
                    !(customers$customer_id %in% ever_member_ids))
  if (length(eligible) < new_member_targets[s_i]) stop("Not enough new member candidates.")
  new_idx <- sample(
    eligible,
    new_member_targets[s_i],
    replace = FALSE,
    prob = unname(member_weights[customers$fan_segment[eligible]])
  )
  new_ids <- customers$customer_id[new_idx]
  new_categories <- sample(STAGE3_CATEGORIES, length(new_idx), replace = TRUE,
                           prob = c(0.43, 0.43, 0.10, 0.04))
  new_seats <- sample(1:4, length(new_idx), TRUE, prob = c(0.20, 0.52, 0.23, 0.05))

  member_ids <- c(renewed$customer_id, new_ids)
  categories <- c(renewed$seat_category, new_categories)
  seats <- c(renewed$seats_per_game, new_seats)
  is_renewal <- c(rep(TRUE, nrow(renewed)), rep(FALSE, length(new_ids)))
  price_index <- match(categories, STAGE3_CATEGORIES)
  price_per_game <- as_cents(
    STAGE3_MEMBER_PRICE_DOLLARS[price_index] *
      (1.035 ^ (s_i - 1L)) * runif(length(member_ids), 0.97, 1.03)
  )
  n_ppg_games <- sum(ppg$season == season)
  year <- season_start_year(season)
  purchase_dates <- as.Date(sprintf("%d-08-15", year)) +
    sample(-14:14, length(member_ids), replace = TRUE)

  block <- data.frame(
    customer_id = member_ids,
    season = season,
    seat_category = categories,
    seats_per_game = as.integer(seats),
    paid_unit_price_cents = as.integer(price_per_game),
    eligible_games = as.integer(n_ppg_games),
    contract_value_cents = as.integer(seats * price_per_game * n_ppg_games),
    purchase_date = as.Date(purchase_dates),
    is_renewal = is_renewal,
    data_origin = "SYNTHETIC",
    stringsAsFactors = FALSE
  )
  member_parts[[s_i]] <- block
  previous <- block
  ever_member_ids <- union(ever_member_ids, member_ids)
  message("Memberships ", season, ": ", nrow(block), " (renewed: ", sum(is_renewal), ")")
}

memberships <- do.call(rbind, member_parts)
rownames(memberships) <- NULL
memberships$membership_id <- sprintf("MEM%06d", seq_len(nrow(memberships)))
memberships$order_id <- sprintf("ORDM%07d", seq_len(nrow(memberships)))
memberships <- memberships[, c("membership_id", "order_id", "customer_id", "season",
                               "seat_category", "seats_per_game", "paid_unit_price_cents",
                               "eligible_games", "contract_value_cents", "purchase_date",
                               "is_renewal", "data_origin")]

# 3) VENUE INVENTORY --------------------------------------------------------
# The category split and holds are hypothetical, not official Penguins inventory.
inv <- expand.grid(seat_category = STAGE3_CATEGORIES, game_id = ppg$game_id,
                   stringsAsFactors = FALSE)
inv <- inv[order(match(inv$game_id, ppg$game_id),
                 match(inv$seat_category, STAGE3_CATEGORIES)), , drop = FALSE]
rownames(inv) <- NULL
inv$season <- ppg$season[match(inv$game_id, ppg$game_id)]
inv$capacity_seats <- STAGE3_CAPACITY[match(inv$seat_category, STAGE3_CATEGORIES)]
inv$held_seats <- pmax(5L, as.integer(round(
  inv$capacity_seats * runif(nrow(inv), 0.006, 0.018)
)))
inv$sellable_seats <- inv$capacity_seats - inv$held_seats
inv$data_origin <- "SYNTHETIC"

# 4) MEMBERSHIP GAME ENTITLEMENTS -------------------------------------------
# This merge yields one line for each member x eligible PPG home game.
rights <- merge(memberships,
                ppg[, c("game_id", "season", "game_date"), drop = FALSE],
                by = "season", all = FALSE, sort = FALSE)
rights <- rights[order(rights$membership_id, rights$game_date), , drop = FALSE]
member_price_index <- match(rights$seat_category, STAGE3_CATEGORIES)
rights_list_cents <- as_cents(
  STAGE3_LIST_PRICE_DOLLARS[member_price_index] *
    (1.035 ^ (match(rights$season, STAGE3_SEASONS) - 1L))
)
member_lines <- make_synthetic_line(
  rights$order_id, rights$game_id, rights$season, rights$customer_id,
  rights$purchase_date, rights$seat_category, "SEASON_MEMBERSHIP",
  rights$seats_per_game, rights_list_cents, rights$paid_unit_price_cents,
  rights$membership_id
)

reserved <- aggregate(quantity ~ game_id + seat_category, member_lines, sum)
inv_key <- paste(inv$game_id, inv$seat_category, sep = "|")
reserved_key <- paste(reserved$game_id, reserved$seat_category, sep = "|")
inv$membership_seats <- reserved$quantity[match(inv_key, reserved_key)]
inv$membership_seats[is.na(inv$membership_seats)] <- 0L
if (any(inv$membership_seats > inv$sellable_seats)) {
  stop("Synthetic memberships oversold one or more seating categories.")
}

# 5) SINGLE-GAME AND GROUP TRANSACTIONS -------------------------------------
# Actual attendance provides a *demand signal*, not a ticket-sales identity.
# Paid sold can differ from reported attendance and never exceed sellable seats.
game_att <- ppg$reported_attendance[match(inv$game_id, ppg$game_id)]
game_weekend <- ppg$is_weekend[match(inv$game_id, ppg$game_id)]
game_weekend[is.na(game_weekend)] <- FALSE
attendance_signal <- pmin(1, pmax(0.70, game_att / 18187))
base_fill <- pmin(0.96, pmax(0.72, 0.76 + 0.18 * (attendance_signal - 0.70) / 0.30))
category_adjust <- c(-0.045, 0.020, 0.032, -0.020)
category_effect <- category_adjust[match(inv$seat_category, STAGE3_CATEGORIES)]
fill_rate <- pmin(0.98, pmax(0.66, base_fill + category_effect +
                             rnorm(nrow(inv), 0, 0.018)))
inv$target_paid_tickets <- pmin(
  inv$sellable_seats,
  pmax(inv$membership_seats,
       as.integer(round(inv$sellable_seats * fill_rate)))
)
inv$other_paid_tickets <- inv$target_paid_tickets - inv$membership_seats

# Game multipliers are synthetic and reproducible; not actual prices.
price_multiplier <- pmin(1.22, pmax(0.89,
  0.93 + 0.14 * (attendance_signal - 0.70) / 0.30 +
    0.04 * as.numeric(game_weekend)
))

# Each nonmembership order has one line. Membership orders have many lines.
# Party sizes are generated in bulk for speed on normal laptops.
customer_pools <- lapply(STAGE3_SEASONS, function(s) {
  which(customers$crm_entry_season <= s)
})
nonmember_parts <- list()
part_number <- 0L
next_order_id <- 0L

for (i in seq_len(nrow(inv))) {
  total <- inv$other_paid_tickets[i]
  if (total == 0L) next

  group_total <- as.integer(round(total * runif(1L, 0.07, 0.14)))
  if (group_total < 6L) group_total <- 0L
  single_total <- total - group_total

  single_sizes <- allocate_party_sizes(single_total, 1L, 5L, 2.9)
  group_sizes <- if (group_total > 0L) {
    allocate_party_sizes(group_total, 6L, 12L, 8.5)
  } else integer(0)
  party_sizes <- c(single_sizes, group_sizes)
  channel <- c(rep("SINGLE_GAME", length(single_sizes)),
               rep("GROUP", length(group_sizes)))
  stopifnot(length(party_sizes) == length(channel), sum(party_sizes) == total)

  season <- inv$season[i]
  game_id <- inv$game_id[i]
  game_idx <- match(game_id, ppg$game_id)
  game_date <- ppg$game_date[game_idx]
  category <- inv$seat_category[i]
  pool <- customer_pools[[match(season, STAGE3_SEASONS)]]
  customer_idx <- sample_customers(customers, pool, length(party_sizes))
  customer_id <- customers$customer_id[customer_idx]
  days_before <- pmin(100L, as.integer(round(
    rgamma(length(party_sizes), shape = 2.0, scale = 10.0)
  )))
  order_date <- pmax(customers$signup_date[customer_idx], game_date - days_before)
  list_price <- as_cents(
    STAGE3_LIST_PRICE_DOLLARS[match(category, STAGE3_CATEGORIES)] *
      (1.035 ^ (match(season, STAGE3_SEASONS) - 1L)) *
      price_multiplier[i]
  )
  price_discount <- ifelse(channel == "GROUP",
                           runif(length(channel), 0.84, 0.92),
                           runif(length(channel), 0.94, 1.00))
  paid_price <- as.integer(round(list_price * price_discount))
  n_orders <- length(party_sizes)
  order_ids <- sprintf("ORDS%08d", next_order_id + seq_len(n_orders))
  next_order_id <- next_order_id + n_orders

  part_number <- part_number + 1L
  nonmember_parts[[part_number]] <- make_synthetic_line(
    order_ids, game_id, season, customer_id, order_date, category,
    channel, party_sizes, rep(list_price, n_orders), paid_price
  )
}

nonmember_lines <- do.call(rbind, nonmember_parts)
rownames(nonmember_lines) <- NULL
order_lines <- rbind(member_lines, nonmember_lines)
rownames(order_lines) <- NULL
order_lines$order_line_id <- sprintf("LINE%08d", seq_len(nrow(order_lines)))
order_lines <- order_lines[, c("order_line_id", setdiff(names(order_lines), "order_line_id"))]

# Orders represent one upfront contract payment OR one single-game/group order.
member_orders <- data.frame(
  order_id = memberships$order_id,
  customer_id = memberships$customer_id,
  season = memberships$season,
  order_date = memberships$purchase_date,
  order_channel = "SEASON_MEMBERSHIP",
  tickets_in_order = memberships$seats_per_game * memberships$eligible_games,
  order_total_cents = memberships$contract_value_cents,
  data_origin = "SYNTHETIC",
  stringsAsFactors = FALSE
)
other_orders <- data.frame(
  order_id = nonmember_lines$order_id,
  customer_id = nonmember_lines$customer_id,
  season = nonmember_lines$season,
  order_date = nonmember_lines$order_date,
  order_channel = nonmember_lines$order_channel,
  tickets_in_order = nonmember_lines$quantity,
  order_total_cents = nonmember_lines$net_revenue_cents,
  data_origin = "SYNTHETIC",
  stringsAsFactors = FALSE
)
orders <- rbind(member_orders, other_orders)
rownames(orders) <- NULL

# 6) SAVE STAGED SYNTHETIC FILES --------------------------------------------
# _draft files only: validator publishes final files after all checks pass.
outputs <- list(
  customers = customers,
  memberships = memberships,
  seat_inventory = inv,
  ticket_orders = orders,
  ticket_order_lines = order_lines
)
for (nm in names(outputs)) {
  saveRDS(outputs[[nm]], file.path(out_dir, paste0(nm, "_draft.rds")),
          compress = "gzip")
}
write.csv(utils::head(order_lines, 200),
          "outputs/tables/synthetic_order_lines_sample.csv", row.names = FALSE)
message("STAGE 3 DRAFT: ", nrow(customers), " customers; ",
        nrow(memberships), " membership contracts; ",
        format(nrow(orders), big.mark = ","), " orders; ",
        format(nrow(order_lines), big.mark = ","), " lines.")
message("Next: source('scripts/05_validate_synthetic_ticketing.R')")
