# Stage 3 Additions — Synthetic Ticketing & Fan Revenue

**Only add these new files to your existing `Penguins-Ticketing-HUB` project.** Do not replace your Stage 2 `R/nhl_helpers.R`, scripts `00`–`03`, or `data/processed/games_real.rds`. No Git initialization is needed.

## Install

Copy these four new files into the matching folders of your existing RStudio project:

- `R/synthetic_helpers.R`
- `scripts/04_build_synthetic_ticketing.R`
- `scripts/05_validate_synthetic_ticketing.R`
- `scripts/06_preview_synthetic_kpis.R`

Also copy `docs/stage3_data_dictionary.md` and `docs/stage3_simulation_assumptions.md` into your project's `docs/` folder.

Open `Penguins-Ticketing-HUB.Rproj` in RStudio. These scripts use Base R plus the `ggplot2` and `scales` packages already installed for Stage 2. No new packages or NHL downloads are required.

## Run in order

```r
source("scripts/04_build_synthetic_ticketing.R")
source("scripts/05_validate_synthetic_ticketing.R")
source("scripts/06_preview_synthetic_kpis.R")
```

**Do not run script 06 if script 05 fails.** Script 04 creates draft files; script 05 audits them and creates the final `.rds` files only if all checks pass. If an error occurs, share the exact Console message and `outputs/tables/stage3_data_quality_checks.csv`.

## Data sources and provenance

- `data/processed/games_real.rds`: actual NHL-derived records from Stage 2. Remains unchanged.
- `data/synthetic/*.rds`: synthetic customers, tickets, inventory, memberships, orders, and business summaries. NOT official Penguins records.
- The model uses actual per-game reported attendance to give hypothetical paid ticket demand realistic variation; **this is not a historical estimate of paid sales**.
- No customer PII is generated; all customer IDs are artificial.
- All transaction amounts are represented in integer **US cents**; divide by 100 for dollar displays.

## Outputs after validation

- `data/synthetic/customers.rds`
- `data/synthetic/memberships.rds`
- `data/synthetic/seat_inventory.rds`
- `data/synthetic/ticket_orders.rds`
- `data/synthetic/ticket_order_lines.rds`
- `data/synthetic/game_business_summary.rds`
- `outputs/tables/stage3_data_quality_checks.csv`
- `outputs/tables/stage3_game_business_summary.csv`
- `outputs/tables/stage3_membership_renewal.csv`
- `outputs/tables/stage3_customer_returning.csv`
- `outputs/tables/stage3_season_kpi_preview.csv`
- `outputs/figures/stage3_synthetic_revenue_by_game.png`

## Expected structural checks

- 122 PPG arena games across three seasons, with four synthetic seating categories each (`488` inventory rows).
- No synthetic transactions for the 2025 Stockholm game.
- Every customer/order/game/membership foreign key connects correctly.
- Every season-ticket membership creates one seasonal purchase, with game-level rights as revenue allocation, *not additional orders*.
- Game-category sales equal their synthetic targets without exceeding sellable inventory.
- Total order payments equal allocated line-level revenue exactly, in whole cents.
- All 35 written data-quality checks pass.
- All synthetic tables use `data_origin = "SYNTHETIC"`. The mixed summary explicitly labels both real and synthetic fields.

## Scope and limitations

This is an educational business simulation, not a price, revenue, subscriber, or fan-behavior estimate issued or verified by the Pittsburgh Penguins or NHL. Seating-category capacity splits, sales channels, renewal behavior, customer segments, conversion/price factors, and membership counts are invented for a realistic *illustrative* business model. No historical source is claimed for those assumptions. Simulated ticket sales are correlated with **observed** attendance by design; this makes them inappropriate as predictors in a historical attendance forecast (target leakage). Train Stage 5 attendance models on permitted pregame **real** features instead.

For Stage 4 Shiny, load the compact `game_business_summary.rds` first. Query the larger synthetic orders/lines only for drill-down views. On shinyapps.io this keeps app startup manageable.
