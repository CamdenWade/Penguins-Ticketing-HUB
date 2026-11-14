# Synthetic-only helpers for Stage 3. Not an NHL or Penguins data source.

STAGE3_SEASONS <- c("2023-24", "2024-25", "2025-26")
STAGE3_CATEGORIES <- c("Upper Bowl", "Lower Bowl", "Center-Ice Club", "Suites & Loges")
STAGE3_CAPACITY <- c(7200L, 8100L, 1800L, 1087L)
STAGE3_LIST_PRICE_DOLLARS <- c(70, 145, 250, 390)
STAGE3_MEMBER_PRICE_DOLLARS <- c(49, 100, 172, 260)
STAGE3_SEED <- 261103L

# Generate randomized party sizes, with an exact number of total seats.
# Vectorized: at most (max_size - min_size) passes.
allocate_party_sizes <- function(total, min_size, max_size, preferred_mean) {
  total <- as.integer(total)
  if (total == 0L) return(integer(0))
  if (total < min_size) stop("Total tickets smaller than minimum party size.")

  n_orders <- as.integer(round(total / preferred_mean))
  n_orders <- max(as.integer(ceiling(total / max_size)), n_orders)
  n_orders <- min(as.integer(floor(total / min_size)), n_orders)

  sizes <- rep(as.integer(min_size), n_orders)
  remaining <- total - sum(sizes)

  while (remaining > 0L) {
    eligible <- which(sizes < max_size)
    if (length(eligible) == 0L) stop("Could not allocate seats.")
    chosen <- eligible[sample.int(length(eligible), size = min(remaining, length(eligible)))]
    sizes[chosen] <- sizes[chosen] + 1L
    remaining <- total - sum(sizes)
  }

  stopifnot(sum(sizes) == total)
  sizes[sample.int(length(sizes))]
}

sample_customers <- function(customers, candidate_indices, n) {
  if (n == 0L) return(integer(0))
  candidate_indices[
    sample.int(
      length(candidate_indices),
      size = n,
      replace = TRUE,
      prob = customers$purchase_weight[candidate_indices]
    )
  ]
}

season_start_year <- function(season) {
  as.integer(substr(season, 1L, 4L))
}

# Currency is stored in whole cents to avoid floating-point reconciliation.
as_cents <- function(dollars) {
  as.integer(round(dollars * 100))
}

make_synthetic_line <- function(order_id, game_id, season, customer_id,
                                order_date, seat_category, order_channel,
                                quantity, list_unit_cents, paid_unit_cents,
                                membership_id = NA_character_) {
  if (length(order_id) == 0L) return(NULL)
  data.frame(
    order_id = as.character(order_id),
    game_id = as.character(game_id),
    season = as.character(season),
    customer_id = as.character(customer_id),
    order_date = as.Date(order_date, origin = "1970-01-01"),
    seat_category = as.character(seat_category),
    order_channel = as.character(order_channel),
    quantity = as.integer(quantity),
    list_unit_price_cents = as.integer(list_unit_cents),
    paid_unit_price_cents = as.integer(paid_unit_cents),
    gross_revenue_cents = as.integer(quantity * list_unit_cents),
    discount_cents = as.integer(quantity * (list_unit_cents - paid_unit_cents)),
    net_revenue_cents = as.integer(quantity * paid_unit_cents),
    membership_id = as.character(membership_id),
    data_origin = "SYNTHETIC",
    stringsAsFactors = FALSE
  )
}
