# Stage 4A — Dashboard metrics and lineage

## Data scopes

- **Real:** `data/processed/games_real.rds`. This contains 123 Pittsburgh-designated 2023–24 through 2025–26 regular-season home games. The Stage 4A app filters to 122 PPG Paints Arena games. The neutral-site Stockholm game remains in the source dataset.
- **Synthetic:** `data/synthetic/game_business_summary.rds`, `ticket_order_lines.rds`, `seat_inventory.rds`. This includes non-official ticket, inventory, price and financial records joined to actual game IDs. No player/team game data is manufactured here.
- **Source labeling:** Attendance visuals display `REAL NHL DATA`; all ticketing and financial visuals display `SYNTHETIC SCENARIO`. CSV exports preserve provenance columns.

## Attendance tab (real NHL)

| KPI | Numerator | Denominator | Caveat |
|---|---|---|---|
| Total reported attendance | Sum of published attendance across selected PPG games | None | Not paid tickets sold |
| Average reported attendance | Sum of reported attendance | Count of selected PPG games | Filter-aware |
| Nominal utilization | Sum of reported attendance | Sum of nominal venue capacity across selected PPG games | Can exceed 100% because reference seating capacity need not equal an event's effective attendance |
| Games analyzed | Count of selected PPG games | None | 122 unfiltered |
| Weekday pattern | Mean of reported attendance within weekday | Number of games in that weekday | Shows counts; do not infer causal effect |
| Opponent draw | Mean of reported attendance per opponent | Number of selected games vs opponent | Small-sample comparisons may be noisy |

## Ticket sales tab (synthetic)

| KPI | Numerator | Denominator | Caveat |
|---|---|---|---|
| Simulated net ticket revenue | Sum `game_business_summary$sim_ticket_revenue_cents` / 100 | None | Earned revenue allocated once across games |
| Simulated paid tickets | Sum `sim_paid_tickets` | None | Includes synthetic membership entitlements |
| Simulated sell-through | Sum `sim_paid_tickets` | Sum `sellable_seats` | Weighted aggregate; never average percentages across games |
| Average paid ticket price | Sum net revenue USD | Sum synthetic paid tickets | Weighted across all ticket categories |
| Seating revenue | Sum `ticket_order_lines$net_revenue_cents` grouped by category / 100 | None | Allocation includes membership game rights |
| Channel ticket volume | Sum synthetic line quantity grouped by `order_channel` | None | Membership entitlement represents tickets per game, not number of membership contracts |

## Filters

All season, opponent, day-type filters first subset the `games_real.rds` PPG subset. The same selected `game_id`s then filter synthetic summaries and aggregates, so tabs remain directly comparable in **game coverage**, not in the meaning of attendance vs paid sales.

## Simulation caveats

The Stage 3 generator partially calibrated ticket demand to actual reported attendance, but it generated customer identifiers, sales channels, capacities, purchasing amounts and membership contracts artificially. Correlations with actual attendance partly reflect the **simulation design**. They are not proof of real sales/attendance relationships and must not be used as independent predictive evidence for real attendance.

The model and deployment stages are intentionally not implemented in Stage 4A.
