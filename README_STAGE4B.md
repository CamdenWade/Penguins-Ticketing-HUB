# Stage 4B — Customer & Membership Analytics (Pittsburgh Penguins Ticketing & Fan Revenue Analytics HUB)

**Add-on to your existing, working Stage 4A RStudio project.** This is not a standalone replacement for Stage 2/3/4A.

## Required existing inputs

- `data/processed/games_real.rds` — validated official attendance (123 designated home games, 122 PPG)
- `data/synthetic/customers.rds` — 35,000 synthetic accounts
- `data/synthetic/memberships.rds` — 7,458 synthetic membership contracts
- `data/synthetic/ticket_orders.rds` — 432,205 synthetic order headers
- `data/synthetic/ticket_order_lines.rds` — 727,847 synthetic ticket lines
- `data/synthetic/game_business_summary.rds` — 122 game-level summaries
- `data/synthetic/seat_inventory.rds` — 488 game-seat-category records

## Installation — preserve your current project

1. Back up the **existing** `app.R` before copying Stage 4B (e.g. `app_stage4a_backup.R`, stored OUTSIDE the project root if you prefer a clean app). Do not delete or overwrite Stage 2/3 datasets.
2. Extract the Stage 4B ZIP **outside** your existing project.
3. Copy `app.R` into the **root** of `Penguins-Ticketing-HUB/`, replacing the existing Stage 4A `app.R`. This is the complete updated application entrypoint.
4. Copy `R/shiny_customer_data.R` and `R/module_customers.R` into your existing `R/` folder.
5. Copy `www/stage4b.css` into your existing `www/` folder. Keep the existing `www/styles.css`; the new CSS extends it.
6. Copy `scripts/09_check_customer_inputs.R` into your existing `scripts/` folder.
7. Copy the two Stage 4B Markdown documents into `docs/`.
8. Open the EXISTING `Penguins-Ticketing-HUB.Rproj` in RStudio. DO NOT initialize Git yet.

## Run in RStudio, from the project root

```r
getwd()                                      # should end in Penguins-Ticketing-HUB
source("scripts/09_check_customer_inputs.R") # validates and writes audit/preview CSVs
shiny::runApp()                              # or click Run App in app.R
```

Stage 4B introduces **no additional R package dependencies** beyond the Stage 4A requirements (`shiny`, `bslib`, `dplyr`, `ggplot2`, `scales`, `DT`). If a dependency is missing:

```r
source("scripts/07_install_shiny_packages.R")
```

The preflight is expected to print **PASS — Stage 4B preflight: 20/20 checks passed.** It uses the exact Stage 3 row counts you previously validated and verifies customer, membership, revenue and ticket summaries.

It writes:
- `outputs/tables/stage4b_data_quality_checks.csv`
- `outputs/tables/stage4b_customer_cohorts.csv`
- `outputs/tables/stage4b_customer_segments.csv`

## New dashboard tab

- **Customer & Membership:** Four selected-game KPI cards, revenue by fan segment, account multi-game activity, segment details with CSV export, weighted full-season renewal/retention KPI cards, historical purchaser status, order-frequency distribution, cohort ledger and export, and an automated business takeaway.
- **Existing tabs remain intact:** Attendance & Demand, Ticket Sales & Revenue, and Methodology.
- **Updated Methodology:** Customer cohort, selection logic, and limitations are documented.

### Critical filters/measurement distinction

Global **season, opponent and weekday/weekend** filters affect the customer **selected-games** section. The full-season **membership renewal** and **purchaser retention** section responds to the **season only**, because filtering the denominator to a few games would be misleading.

- Renewal (2024–25 and 2025–26): members in immediately prior season who renewed / members eligible from prior season.
- Purchaser retention (2024–25 and 2025–26): accounts with any purchase in the previous season who also purchased in current season / previous-season purchasing accounts.
- 2023–24: cohort baseline. There is no observed prior season and the rates show **— / N/A**, never zero.
- First-observed account: first synthetic purchase recorded in the three-season window; NOT necessarily a new hockey fan in the real world.
- Season-ticket contract: ONE order/payment, 40–41 game entitlements allocated to the corresponding home games. Never count it as 40–41 purchase orders.
- Paid entitlements / ticket rights do NOT prove physical game attendance.

**Important:** The project is an educational, unaffiliated portfolio simulation. No Penguins financial or CRM records were used, and none of the customer-level inferences are about actual Penguins fans.

## Acceptance checklist

1. Run `source("scripts/09_check_customer_inputs.R")` and get 20/20 `TRUE` checks.
2. Launch with `shiny::runApp()`; see four navigation tabs.
3. All seasons: Customer tab shows revenue from selected games matching Stage 4A synthetic game revenue.
4. Change season to 2023–24: renewal and purchaser retention should be unavailable (`—` or N/A).
5. Change season to 2024–25 or 2025–26: both rates should be populated between 0 and 100%.
6. Change opponent/weekday: selected-game account metrics change, but full-season renewal/retention do **not** change.
7. Change season: full-season renewal/retention changes accordingly.
8. Reset filters: returns to all 122 PPG home games.
9. Verify both synthetic CSV download buttons and original Attendance/Revenue navigation still work.
10. Confirm Methodology describes the synthetic-only CRM simulation.

## Troubleshooting

- `Missing ... .rds`: open the original `.Rproj`; confirm `getwd()` and that Stage 3 validation produced the final `.rds` files.
- A count/provenance check fails: **do not regenerate random data** or bypass validations. Copy the exact R error and the check CSV for review.
- `could not find function ...`: verify new files are in `R/` (not nested under `Stage4B-Additions/`) and copied the new root `app.R`.
- Styles missing: `www/styles.css` and `www/stage4b.css` must both exist. Reload the browser window.
- Slow first load: aggregation of ~728k synthetic lines occurs at startup, not on every filter change. Filter operations then work on compact derived tables.

No Git or deployment changes are made by this stage. Stage 5 will add a historical-attendance forecasting component based on **real game data**, not synthetic ticket sales.
