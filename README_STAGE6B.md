# Stage 6B — Shinyapps.io deployment

## What this adds

Keep your current local `app.R`, existing modules, saved datasets, trained models and Git repository unchanged. Add:

- `scripts/16_build_deployment_bundle.R`
- `scripts/17_verify_deployment_bundle.R`
- `scripts/18_deploy_shinyapps.R`
- `R/deploy_loaders.R`
- Replace project-root `.gitignore` with the supplied version **after reviewing existing tracked paths**.

The Stage 6B build creates **`deployment/runtime/`**, a separate working deployment app. It copies the existing Stage 5B UI, module files and CSS, then adds a deployment-only loader and three compressed RDS reporting snapshots. The original app remains unchanged and will continue using the raw local Stage 2–5B files.

The deployed version does not need to load the 727,847-row ticket order-line file and 432,205-row orders file at startup; it loads pre-aggregated reporting snapshots. The customer-game table can still be sizeable, but this approach avoids repeated transformations and redundant raw data in the deployment bundle.

## Run in RStudio (project root)

```r
install.packages("rsconnect")
source("scripts/14_check_forecast_dashboard.R")
source("scripts/16_build_deployment_bundle.R")
source("scripts/17_verify_deployment_bundle.R")
shiny::runApp("deployment/runtime")
```

Inspect all five tabs and reset filters/exports. Close the local app before deploying.

## Connect account safely

Visit https://www.shinyapps.io/, sign in, then Account -> Tokens. Copy shinyapps.io's R code for `rsconnect::setAccountInfo(...)` and run it **in your local RStudio Console only**. Do not put the token or secret in a script, screenshot, README, GitHub, or this conversation. If you previously used shinyapps.io, your account may already be configured.

Then run:

```r
source("scripts/18_deploy_shinyapps.R")
```

Alternatively, in RStudio use **Publish** for the `deployment/runtime` folder (not the root development project) after completing the preflight.

## Post-deploy acceptance checks

1. All five tabs render, including the Methodology tab.
2. Unfiltered 122 games, real attendance metrics and synthetic revenue totals match the local version.
3. Customer cohorts for 2024–25 and 2025–26 show appropriately labeled synthetic rates.
4. Backtest has 40 historical holdout games, selected model `historical_mean`, MAE ≈ 1,173.
5. Default revenue scenario yields 33,041 extra hypothetical tickets and $2,973,690 added hypothetical revenue.
6. Filters update correctly, and zero conversion yields zero added revenue; full conversion never exceeds seats.
7. Download tables and Reset Filters work.
8. Test in a private browser window and on mobile. Shinyapps.io may put idle apps to sleep and restart when visited.
9. If deployment fails, use `rsconnect::showLogs(appName="penguins-ticketing-hub", account="YOUR_ACCOUNT")` and inspect the first startup error.
10. Only after a successful live test, paste the verified URL into the GitHub repository About -> Website and README.

## Security and publication caution

The current public GitHub `.gitignore` was short at review time. The supplied longer `.gitignore` prevents **new, untracked** data files being added, but it **does not remove files already tracked**. Before pushing new commits, run from RStudio's Terminal:

```bash
git ls-files data models outputs deployment rsconnect
git status --short
```

If generated assets are tracked, don't use `git add -A` blindly. Carefully untrack them using `git rm -r --cached -- data/processed data/synthetic data/modeling models outputs` (only paths that actually exist/tracked), then commit. Untracking does **not** remove files from your local working tree. Since old commits still retain previously committed objects, review whether any sensitive or confidential material was exposed before relying on this fix. This simulation uses anonymous synthetic IDs, but always inspect files for secrets.

Avoid committing `deployment/runtime/`, since the runtime snapshots contain potentially large synthetic customer-level reporting rows. Deploy from local RStudio to shinyapps.io directly.

## Package setup

The runtime imports `shiny`, `bslib`, `dplyr`, `ggplot2`, `scales`, and `DT`; shinyapps.io installs detected R dependencies. Ensure your local R version and package versions are compatible with shinyapps.io. If you encounter unavailable packages or memory limits, inspect the deployment logs and plan/account limits. Once the live app runs, record the Shiny URL and test it independently.
