# Pittsburgh Penguins Ticketing & Fan Revenue Analytics HUB
## Stage 4A — Interactive R Shiny foundation

**Important:** This archive contains **additions** to your already-completed Stage 2 and Stage 3 project. It does not contain the user's validated data, and it does not initialize Git.

### Install into the existing project

1. Quit any running Shiny session. Extract this ZIP to a temporary folder.
2. Copy `app.R` into the top level of the existing `Penguins-Ticketing-HUB` folder (beside `Penguins-Ticketing-HUB.Rproj`).
3. Copy the four new files from `R/` into the existing `R/` folder.
4. Copy the two scripts from `scripts/` into the existing `scripts/` folder.
5. Copy `www/styles.css` into a new `www/` folder under the existing project root.
6. Copy both `docs/` markdown documents into your existing `docs/` folder.
7. Keep all existing `R/nhl_helpers.R`, `R/synthetic_helpers.R`, `scripts/00`–`06`, `data/` and `outputs/` files. Do **not** rebuild the 727k synthetic order lines just to launch Shiny.

### In RStudio

```r
getwd() # should end in Penguins-Ticketing-HUB
source("scripts/07_install_shiny_packages.R")
source("scripts/08_check_shiny_inputs.R")
shiny::runApp()
```

Or open `app.R` and click **Run App**.

**If you get `Missing Shiny packages`:** run the installer file first, restart R if needed, then run the preflight script again.

**If you get `Stage 4A requires validated Stage 2 and 3 files`:** check that `data/processed/games_real.rds`, `data/synthetic/game_business_summary.rds`, `data/synthetic/seat_inventory.rds` and `data/synthetic/ticket_order_lines.rds` exist in the same project opened by RStudio.

### Features

- Global season, opponent and weekday/weekend selectors, plus reset.
- **Attendance & Demand (REAL):** total and average attendance, published-capacity utilization, historical trends, day-of-week and opponent comparisons, downloadable filtered game ledger.
- **Ticket Sales & Revenue (SYNTHETIC):** net ticket revenue, ticket volume, weighted sell-through, average price, revenue by game/category, ticket channel mix, downloadable filtered game ledger.
- **Methodology:** real vs synthetic sourcing and precise metric definitions.
- Dark black-and-gold theme with responsive layouts. No third-party logos or images required.

### Performance and accounting safeguards

Stage 3's `ticket_order_lines.rds` is large (727,847 lines in your validated run). It is read once at launch, aggregated by `game_id × seat_category` and `game_id × order_channel`, reconciled to `game_business_summary.rds`, then released from the in-memory loader. Filters operate on just 122 game summaries and a few hundred aggregates.

Net revenue is always calculated from Stage 3 **game-level earned revenue allocations**. Do not add the full membership `ticket_orders$order_total_cents` to the game allocations: that would double-count season membership purchases.

### Data disclosure

This is an independent **educational portfolio**. Historical game information and reported attendance come from official NHL sources. All customer, ticket transaction, seat inventory, sales, prices, membership and revenue figures are synthetic, and are **not** actual or estimated Pittsburgh Penguins ticketing data. No affiliation with the team or league is claimed.

### Not included yet

- Stage 4B: customer analytics and membership renewal dashboards.
- Stage 5: predictive attendance model and revenue scenarios.
- Stage 6: GitHub, deployment and portfolio website integration.

See `docs/stage4a_kpi_definitions.md` and `docs/stage4a_demo_walkthrough.md`.
