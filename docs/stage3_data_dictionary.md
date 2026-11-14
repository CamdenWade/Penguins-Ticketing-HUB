# Stage 3 synthetic data dictionary

All Stage 3 values except the join to the validated NHL Stage 2 games are **fully synthetic**. Tables under `data/synthetic/` are linked by text identifiers. All prices/revenue fields are integer **USD cents** (divide by 100 for dollars). All records include `data_origin = SYNTHETIC` except `game_business_summary`, which carries two explicit origin labels.

## customers.rds
- `customer_id` — Unique anonymous synthetic customer key.
- `crm_entry_season`, `signup_date` — Synthetic cohort and CRM creation date.
- `fan_segment` — Simulated latent segment (not derived from NHL fans).
- `purchase_weight` — Synthetic per-customer probability weight used to create repeat buying patterns; not a model score or actual propensity.
- `data_origin` — `SYNTHETIC`.

## memberships.rds
- `membership_id` — Unique contract-per-season key.
- `order_id` — One prepaid membership purchase per season; links to `ticket_orders`.
- `customer_id`, `season` — Customer and covered season.
- `seat_category`, `seats_per_game` — Simulated committed seats per PPG game.
- `paid_unit_price_cents` — Per-seat per-game fixed recognized price.
- `eligible_games` — 41 / 41 / 40 PPG games in the three seasons.
- `contract_value_cents` — Seats × per-game price × eligible games.
- `purchase_date` — Simulated annual purchase date.
- `is_renewal` — Whether customer held a membership in the immediately preceding season.
- `data_origin` — `SYNTHETIC`.

## seat_inventory.rds
Each row is a `game_id × seat_category` inventory partition.
- `capacity_seats` — Hypothetical division of 18,187 nominal seats.
- `held_seats` — Simulated seats reserved from sale.
- `sellable_seats` — Capacity minus holds.
- `membership_seats` — Seats committed to season members.
- `target_paid_tickets` — Synthetic paid demand target (includes memberships).
- `other_paid_tickets` — Target minus membership commitments.
- `data_origin` — `SYNTHETIC`.

## ticket_orders.rds
Each row is one synthetic purchase (`order_id`).
- `order_id`, `customer_id`, `season`, `order_date` — Purchase identifier, buyer, season, date.
- `order_channel` — `SEASON_MEMBERSHIP`, `SINGLE_GAME`, `GROUP`.
- `tickets_in_order` — Total seats purchased, including all covered games for a membership.
- `order_total_cents` — Total payment for the complete purchase. **Cash/purchase measure**; do not add membership order amounts again on every game.
- `data_origin` — `SYNTHETIC`.

## ticket_order_lines.rds
Each row is an order line and a specific game entitlement. `order_id` may repeat for membership orders across games.
- `order_line_id` — Unique line key.
- `order_id`, `game_id`, `season`, `customer_id` — References to purchase, game, season and buyer.
- `order_date`, `seat_category`, `order_channel`, `quantity` — Purchase details.
- `list_unit_price_cents`, `paid_unit_price_cents` — Hypothetical list and paid per-seat prices.
- `gross_revenue_cents` — Quantity × list unit price.
- `discount_cents` — Gross minus net.
- `net_revenue_cents` — Quantity × paid unit price. **Game-level recognized revenue allocation**.
- `membership_id` — Membership contract for entitlement lines; `NA` for other channels.
- `data_origin` — `SYNTHETIC`.

## game_business_summary.rds
One row per real PPG home game.
- `game_id`, `season`, `game_date`, `opponent`, `reported_attendance` — REAL_NHL game reference and attendance.
- `sim_paid_tickets`, `sim_ticket_revenue_cents` — Fully synthetic paid volume and net revenue allocation.
- `sellable_seats`, `capacity_seats`, `sim_sellthrough`, `sim_revenue_per_paid_ticket` — Simulated inventory and derived KPIs.
- `real_attendance_origin` = `OFFICIAL_NHL_GAME_SUMMARY`.
- `financial_data_origin` = `SYNTHETIC`.

## KPI denominators
- **Reported attendance** = actual attendance from official NHL reports for PPG home games.
- **Simulated paid ticket sell-through** = `sum(sim_paid_tickets) / sum(sellable_seats)` (never use mean of game rates for a full-season aggregate without checking weights).
- **Simulated net ticket revenue** = `sum(net_revenue_cents) / 100` on lines or `sum(order_total_cents) / 100` on orders, **not both**.
- **Simulated average paid ticket price** = `sum(net_revenue_cents) / sum(quantity) / 100`.
- **Simulated membership renewal rate for season S** = previous season's members also buying a contract for S / previous season's members. Not defined for 2023-24 without a 2022-23 membership baseline.
- **Simulated returning-customer rate** = buyers in season S with at least one earlier purchase *within the three-season observation window* / unique buyers in S. For 2023-24, all customers are first observed; it is not a meaningful pre-project retention benchmark.
