# Data sources, boundaries and ethical use

## Real game data

The real historical table covers three completed Pittsburgh Penguins NHL regular seasons (2023–24 through 2025–26). `scripts/01_build_games_real.R` downloads schedules from the public NHL team schedule endpoint and reads attendance from the NHL HTML game-summary reports.

- NHL season schedule example: https://api-web.nhle.com/v1/club-schedule-season/PIT/20252026
- NHL official game report example: https://www.nhl.com/scores/htmlreports/20252026/GS020013.HTM
- Arena nominal capacity reference: https://www.ppgpaintsarena.com/consol_energy_center/faqs

### Definitions and scope

- Source game rows = 123 designated Penguins home games.
- Arena-specific reporting = 122 regular-season games at PPG Paints Arena.
- November 16, 2025 vs. Nashville was an international designated home game played at Avicii Arena, Stockholm, so it is excluded from PPG-only KPIs.
- Reported NHL attendance is **not** a measurement of paid tickets sold, synthetic seat inventory, or ticket revenue.
- `18,187` is a nominal reference capacity, not a claim about each game's inventory. Do not cap actual attendance at 18,187 merely to force utilization below 100%.

The data pipeline stores `schedule_source_url`, `report_source_url`, and `data_origin`; missing reports are treated as failures, not replaced with estimates.

## Entirely synthetic business data

Generated in Stage 3 with reproducible R code:

- Anonymous customer accounts, customer segments, new/returning classifications
- Seating allocations, season membership contracts and renewals
- Tickets, order headers, purchases, discounts, paid ticket volumes
- Ticket prices, net revenue, channels, sell-through and revenue opportunities

These are fictional records. Values are not actual, leaked, licensed, or statistically estimated Pittsburgh Penguins commercial data. No real fan or customer personal details are included.

The simulator is partly calibrated to historical attendance patterns, so synthetic sales are not an independent observation of attendance. For this reason the Stage 5A attendance model deliberately uses **only real pregame calendar/schedule predictors**.

## Model estimates and what-if assumptions

- **Retrospective attendance predictions** are out-of-time estimates for already-completed games; they are not predictions for upcoming games.
- **What-if results** come from user-controlled hypothetical conversion, price, and marketing-cost assumptions; they are not probabilities, price-elasticity estimates, profit forecasts, or official revenue opportunities.
- Revenue allocated from a season-membership purchase across game entitlements is not recognized again as a separate full membership payment in every game.

## Attribution and branding

Independent educational portfolio. No affiliation with or endorsement from the Pittsburgh Penguins, NHL, PPG Paints Arena, or their owners/sponsors. Black-and-gold styling and an original `P` monogram are used for visual context; official logos, protected imagery and official brand assets are not packaged with the application. Screenshot images in `docs/screenshots/` depict the user's own educational dashboard.

For current source rights, usage restrictions, or republishing of scraped data, review the source providers' terms. This repository publishes the acquisition code, not third-party cached HTML or JSON reports.
