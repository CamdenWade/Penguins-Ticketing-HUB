# Stage 5A — Real NHL Attendance Forecasting (Historical Backtest)

**Pittsburgh Penguins Ticketing & Fan Revenue Analytics HUB**  
**Stage:** 5A — reproducible model development, model selection, time-based testing and diagnostics.  
**IMPORTANT:** This is an *add-on* for the existing, working Stage 4B RStudio project, **not** a new project. **Do not initialize Git yet.**

## What it does

Trains and evaluates a restrained, interpretable attendance forecasting workflow on validated, official NHL **reported attendance** for **122 games played at PPG Paints Arena** across 2023–24, 2024–25, and 2025–26. The November 16, 2025 Stockholm-designated home game remains in your original real-game data but is **excluded** from modeling.

Two model families are evaluated:

1. **Historical-mean baseline** — a simple benchmark trained on the games available at each training stage.
2. **Penalized linear (ridge) model** — uses only pregame schedule-derived features; standardized on training data; no external modeling package required.

**Strict out-of-time workflow:**

| Season | Games | Purpose |
|---|---:|---|
| 2023–24 | 41 | Fit candidate models and compare penalty settings |
| 2024–25 | 41 | Choose ridge lambda, then decide if ridge beats the historical mean by a predefined 50 fans/game MAE margin |
| 2023–24 + 2024–25 | 82 | Refit both final models using development data only |
| 2025–26 | 40 | Final untouched held-out backtest; evaluate both, report selected model |

### Why model choice happens before the test

The 2025–26 attendance outcomes are **never** used for penalty tuning, model selection, coefficient fitting, or data preprocessing. The model is selected using **2024–25 validation MAE**. If the best ridge result doesn't improve MAE by at least 50 fans/game, the simpler mean baseline stays selected. This threshold is pre-specified in `R/attendance_model_helpers.R`. Both final models' 2025–26 results are displayed transparently, even when the baseline wins.

There are only 41 games in the validation season, so the comparison can be noisy. A more complex model is **not** guaranteed to win.

## Inputs (from your existing Stage 2 project)

- `data/processed/games_real.rds` — 123 designated home games, 122 at PPG Paints Arena, with zero missing official attendance; provenance `REAL_NHL`.

**Not used anywhere by the model:** synthetic sales, ticket prices, memberships, customer CRM, game scores, final results, in-game variables, or attendance-derived predictors.

The original Stage 2/3 `.rds` datasets, existing scripts, and Stage 4A/4B Shiny app stay untouched.

## Install these files in the EXISTING project

Extract the Stage 5A zip **outside** the project folder. Copy each file into the corresponding existing folder:

```
Penguins-Ticketing-HUB/
├── app.R                                (KEEP — existing Stage 4B)
├── R/
│   ├── nhl_helpers.R                    (KEEP)
│   ├── synthetic_helpers.R              (KEEP)
│   ├── shiny_data.R                     (KEEP)
│   ├── shiny_helpers.R                   (KEEP)
│   ├── module_attendance.R              (KEEP)
│   ├── module_revenue.R                 (KEEP)
│   ├── shiny_customer_data.R            (KEEP)
│   ├── module_customers.R               (KEEP)
│   └── attendance_model_helpers.R        NEW
├── scripts/
│   ├── 00_install_packages.R            (KEEP)
│   ├── ...                              (KEEP all Stage 1–4 scripts)
│   ├── 10_prepare_attendance_features.R  NEW
│   ├── 11_train_attendance_models.R      NEW
│   ├── 12_diagnose_attendance_models.R   NEW
│   └── 13_validate_attendance_models.R   NEW
├── data/
│   ├── raw/                             (KEEP)
│   ├── processed/games_real.rds         (KEEP — read-only source)
│   ├── synthetic/                       (KEEP)
│   └── modeling/                        CREATED by scripts
├── models/                              CREATED by scripts
├── outputs/
│   ├── figures/                         (additional Stage 5A PNG files)
│   └── tables/                          (additional Stage 5A CSV files)
├── www/                                (KEEP all existing CSS)
└── docs/
    ├── ...                             (KEEP)
    ├── stage5a_model_card.md             NEW
    └── stage5a_feature_dictionary.md    NEW
```

No package installation beyond the packages already installed for Stage 4A is needed. The training and evaluation helpers use base R `stats`, and the diagnostics script uses `ggplot2` and `scales` (already present in your Shiny project). If needed:

```r
source("scripts/07_install_shiny_packages.R")
```

## RStudio step-by-step

1. Open the **existing** `Penguins-Ticketing-HUB.Rproj` (do not start a new RStudio project).
2. Run `getwd()`; verify the project root (the folder containing `app.R`, `R`, `scripts`, and `data`).
3. Make sure `data/processed/games_real.rds` exists and Stage 2's audit still passes.
4. Run these, one at a time, from the RStudio Console:

```r
source("scripts/10_prepare_attendance_features.R")
source("scripts/11_train_attendance_models.R")
source("scripts/12_diagnose_attendance_models.R")
source("scripts/13_validate_attendance_models.R")
```

If a script stops, **do not run the remaining scripts** until you fix the error. Do not change row-count or no-leakage guards to force a PASS.

### Expected data counts

- `10_prepare`: 122 PPG games, training 41, validation 41, test 40; no missing attendance.
- `11_train`: validation score table (1 historical-mean + 6 ridge penalties), final 2025–26 comparison (2 model rows); numbers only emerge after you run the code.
- `12_diagnose`: three PNG plots and a CSV error summary by calendar month.
- `13_validate`: all checks must be `TRUE` and `PASS — Stage 5A attendance model is ready for review.`

**We have not predetermined the model MAE, RMSE, or the winning model**. These must come from the completed R run, not guessed values.

## Outputs (new only)

| Output file | Why it matters |
|---|---|
| `data/modeling/attendance_features.rds` | Reproducible pregame predictor table |
| `data/modeling/attendance_features.csv` | Readable, auditable features |
| `data/modeling/attendance_holdout_predictions.rds` | Full-season untouched backtest predictions |
| `models/attendance_model_bundle.rds` | Both fitted models, validation results, split metadata, provenance and selected model |
| `models/attendance_selected_model.rds` | Final selected model only |
| `outputs/tables/stage5a_split_audit.csv` | Input source and split sizes |
| `outputs/tables/stage5a_validation_model_scores.csv` | Candidate lambda selection on 2024–25 |
| `outputs/tables/stage5a_holdout_metrics.csv` | MAE/RMSE/bias on 2025–26 |
| `outputs/tables/stage5a_holdout_predictions.csv` | Actual vs predicted per game, both models |
| `outputs/tables/stage5a_holdout_error_by_month.csv` | Small descriptive segment error summary |
| `outputs/tables/stage5a_data_quality_checks.csv` | Independent quality / anti-leakage audit |
| `outputs/figures/stage5a_actual_vs_predicted.png` | Chronological observed-vs-predicted series |
| `outputs/figures/stage5a_accuracy_scatter.png` | Comparison to ideal diagonal |
| `outputs/figures/stage5a_residuals_by_game.png` | Signed game errors over time |

## Interpreting the results

**MAE** = the average absolute difference between published reported attendance and predicted attendance, in **fans per game**. **RMSE** emphasizes larger misses. **Bias** is average *predicted minus actual*; positive means over-prediction.

A test-season sample of just 40 games provides a useful demonstration, not a production-grade error guarantee. Historical season shocks, opponent popularity, injuries, promotions, team form, calendar changes, and non-public box-office information can cause shifts in real attendance. The chosen feature set intentionally excludes anything that couldn't be known before the game.

The model does not forecast actual paid ticket sales, ticket revenue, physical turnstile scans, or causal promotional uplift. It is **not a live future-game forecasting service**: it is an out-of-time test on an already completed season. Stage 5B will add a clearly labeled, illustrative Shiny model-explanation and revenue-scenario interface after these checks pass.

## Send back for model review

After you run the scripts, please send:

1. The printed 2024–25 validation scores and selected model/lambda.
2. The printed 2025–26 holdout MAE/RMSE table.
3. The final audit count (`... / ... passed`).
4. Optional screenshot of `stage5a_actual_vs_predicted.png`.

Do not initialize Git or update `app.R` yet; Stage 6 will handle version control and deployment.
