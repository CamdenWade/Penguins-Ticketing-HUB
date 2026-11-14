# Stage 5B — Historical Attendance Backtest & Synthetic Revenue Opportunities

## Intended use

Merge these **additions** into your **existing, working Stage 4B RStudio project**. Do not replace the existing project folder wholesale. The module requires Stage 5A (scripts 10–13) to have completed successfully with **37/37 model checks**. This package does not modify or refit Stage 5A models, or regenerate Stage 2/3 datasets.

The dashboard makes a strict distinction:

- **Real source observations:** Official NHL game attendance for 2025–26, at PPG Paints Arena only.
- **Historical model backtest:** Precomputed model predictions for the same 40 games, made using an 82-game development set. **Not future-game forecasts.**
- **Synthetic scenario:** Unsold seats, sales, ticket prices, assumed extra sales, and revenue. **Not Penguins financial data, actual sales opportunities or a prediction of demand.**

## Install these files in the current project

```text
Penguins-Ticketing-HUB/
├── app.R                            REPLACE (back up old app.R first)
├── Penguins-Ticketing-HUB.Rproj     KEEP
├── R/
│   ├── ...existing R files...       KEEP
│   ├── shiny_opportunity_helpers.R  ADD
│   ├── shiny_forecast_data.R        ADD
│   └── module_forecast.R            ADD
├── scripts/
│   ├── ...scripts 00–13...          KEEP
│   └── 14_check_forecast_dashboard.R ADD
├── www/
│   ├── styles.css                   KEEP
│   ├── stage4b.css                  KEEP
│   └── stage5b.css                  ADD
├── docs/
│   ├── ...existing docs...          KEEP
│   ├── stage5b_methodology.md       ADD
│   └── stage5b_demo_walkthrough.md  ADD
├── data/
│   ├── processed/games_real.rds      KEEP
│   ├── synthetic/*.rds              KEEP
│   └── modeling/attendance_holdout_predictions.rds KEEP
├── models/attendance_model_bundle.rds KEEP
└── outputs/                        KEEP
```

### Mac/RStudio: step-by-step

1. **Save a copy** of the working Stage 4B `app.R`, e.g., `app_stage4b_backup.R` outside the project if you prefer.
2. Download and **extract** this ZIP in a separate temporary folder. Copy the new files into your current project's matching folders. Only the old `app.R` is overwritten. **Keep all prior scripts, data and CSS.**
3. Open `Penguins-Ticketing-HUB.Rproj` and confirm `getwd()` ends with `Penguins-Ticketing-HUB`.
4. If Shiny packages are missing, run:
   ```r
   source("scripts/07_install_shiny_packages.R")
   ```
5. **Run the full Stage 5B preflight before starting Shiny**:
   ```r
   source("scripts/14_check_forecast_dashboard.R")
   ```
   It writes `outputs/tables/stage5b_dashboard_checks.csv`. Every row's `passed` value must be `TRUE`. If it fails, **do not launch**; inspect the failed check first.
6. Start the application:
   ```r
   shiny::runApp()
   ```
7. Select the new **Forecasting & Opportunities** tab. Open in a full browser for the best layout.

### Expected preflight coverage

The preflight loads the existing Stage 4A aggregates and Stage 5A model artifacts. It checks the 122 PPG games, 488 game-seat aggregates, 366 game-channel aggregates, 40 held-out predictions, data provenance, selected model, exact performance reconciliation, inventory limits, zero- and full-conversion edge cases, default 15% scenario accounting, game filters and unchanged source RDS checksums. The script reports its actual checks-passed count at runtime.

**Known verified historical modeling results** (from your Stage 5A run):

| Model | Holdout MAE | Holdout RMSE | Selection |
|---|---:|---:|---|
| Historical mean | 1,172.616 | 1,445.668 | Selected on 2024–25 validation |
| Ridge | 1,128.597 | 1,385.524 | Challenger only |

Do not reselect ridge just because it has lower error on the held-out 2025–26 season.

## Dashboard behavior

- The **model KPI cards** always display metrics for the entire 40-game **2025–26 historical test**. They are deliberately unchanged by game filters.
- The **backtest chart and ledger** honor global season/opponent/weekday filters. If a filter excludes all 2025–26 games, they show no match. This is expected, not an error.
- The **synthetic opportunity scenario** uses whichever of the 122 PPG games match global filters, across any of the three seasons. Sliders control the fraction of unsold seats converted, assumed net price per extra ticket and hypothetical acquisition spend per extra ticket.
- Extra tickets are calculated as `floor(unsold synthetic seats * capture_pct / 100)` **per game**. Extra tickets never exceed available hypothetical seat inventory.
- The "revenue less marketing spend" figure does not reflect profit. All other operating costs, price sensitivity, cannibalization and consumer behavior are excluded.
- The backtest and scenario tables can be exported as CSV. Their source labels travel with the files.

## Manual acceptance checklist

1. Attendance, Revenue and Customer & Membership tabs are unchanged and still function.
2. The preflight passes and `.Rproj` project has no missing files.
3. Fourth tab loads without RStudio warnings/errors.
4. With **All seasons**, historical chart/ledger contains 40 held-out games while the simulator includes 122 games.
5. With **2023–24**, historical test chart shows no matching held-out games; simulator contains 41 games.
6. With **2025–26**, historical test chart contains 40 games; simulator contains 40 games.
7. Opponent/weekend filters alter both selected-game views, not the fixed 40-game backtest metric cards.
8. Set **0% conversion**: zero incremental tickets and $0 added revenue.
9. Set **100% conversion**: simulated sell-through reaches 100% for all selected games (subject to synthetic inventory).
10. Changing assumed price increases/decreases gross incremental ticket revenue. Changing assumed marketing cost affects only after-cost illustration, not added gross revenue.
11. Export both CSVs. Check columns clearly distinguish `REAL_NHL`, historical `MODEL_ESTIMATE`, and `SYNTHETIC` / `USER_ASSUMPTIONS_NOT_A_FORECAST`.
12. Go to Methodology and verify the two new explanatory cards appear.

## Troubleshooting

- **Missing Stage 5A artifacts**: run scripts 10–13 in order, ensuring `37/37` checks, then run script 14.
- **Stage 5A model/source checksum mismatch**: do not manually edit saved prediction/model files; rerun the Stage 5A training and audit pipeline if the official real-data file changed.
- **Missing CSS / blank fourth tab**: confirm `www/stage5b.css` and all three new `R/` files exist, and that the **updated** `app.R` is at the root.
- **No backtest games with 2023–24 selected**: correct behavior — only 2025–26 was the held-out test season.
- **The scenario shows unusually large dollars**: it is a three-season fictional exercise; use filters to scope the scenario and remember that the inputs are assumptions, not forecasts or official Penguins data.
- **Sliders are slow**: preflight once, then restart R before `shiny::runApp()`. Stage 5B uses only preaggregated 122-game synthetic summaries; it does not recalculate the 727,847 raw order lines per interaction.

No Git initialization or remote publishing occurs in Stage 5B.
