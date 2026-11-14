# Reproducibility and data build guide

The public GitHub repository is designed as a **source-code repository**, not a repository of generated data and pre-fitted models. A fresh clone will not immediately run `shiny::runApp()` until its data/model dependencies are recreated.

## Environment

Use a current R and RStudio installation on macOS, Windows, or Linux. Stage 2 package installer: `scripts/00_install_packages.R`; Shiny package installer: `scripts/07_install_shiny_packages.R`. Keep a log of `sessionInfo()` when reproducing results. For Stage 6B, a package lockfile may be introduced after verifying server compatibility, rather than prematurely freezing local packages.

## Build order

Run from the RStudio project root:

```r
source("scripts/00_install_packages.R")
source("scripts/07_install_shiny_packages.R")
source("scripts/01_build_games_real.R")
source("scripts/02_validate_games_real.R")
source("scripts/03_preview_attendance.R")
source("scripts/04_build_synthetic_ticketing.R")
source("scripts/05_validate_synthetic_ticketing.R")
source("scripts/06_preview_synthetic_kpis.R")
source("scripts/08_check_shiny_inputs.R")
source("scripts/09_check_customer_inputs.R")
source("scripts/10_prepare_attendance_features.R")
source("scripts/11_train_attendance_models.R")
source("scripts/12_diagnose_attendance_models.R")
source("scripts/13_validate_attendance_models.R")
source("scripts/14_check_forecast_dashboard.R")
source("scripts/15_check_git_publication.R")
shiny::runApp()
```

The NHL API requests require an internet connection and may be subject to rate limits or service changes. The simulator generates synthetic records with a fixed seed. If new data or code changes, model results can differ from the author's completed historical run; rerun all validation checks rather than assuming a prior result still applies.

## Local files deliberately omitted from Git

`data/raw/`: downloaded HTML and JSON source caches. 

`data/processed/`: validated real NHL game-level RDS and CSV.

`data/synthetic/`: potentially large generated CRM, order, entitlement and summary RDS files.

`data/modeling/` and `models/`: derived features, model selections, predictions and fitted model objects.

`outputs/`: generated QA reports and plots.

`rsconnect/`: shinyapps.io deployment metadata; `.Renviron`, `.env`, credentials and tokens also ignored.

**Do not delete these directories from your currently working local project.** Git ignoring them only changes what gets committed, not what is available to `shiny::runApp()` locally. Stage 6B will create an explicit deployment bundle containing the minimum required RDS files, separately from the GitHub source commit.

## Publication safeguards

- Do not commit authentication secrets, API tokens or session files.
- Keep the existing Stage 2–5B validation audits locally and rerun them after a data change.
- Check all staged files with `git diff --cached --name-only` before the first push.
- Maintain the visible REAL/SYNTHETIC provenance distinctions in the UI and exports.
- Add a shinyapps.io link to README only after independently checking the deployed app.
