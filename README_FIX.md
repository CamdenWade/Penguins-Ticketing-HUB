# Stage 6B — Hotfix for missing `data/processed` and `data/synthetic` files

This fixes the previously generated deployment version calling the **development** loaders instead of reading its self-contained reporting snapshots.

## Fastest path (no new data-generation run)

1. Stop Shiny with the red Stop button or Esc in RStudio.
2. Copy `scripts/19_fix_runtime_loader.R` and the corrected `scripts/17_verify_deployment_bundle.R` from this ZIP into the existing project `scripts/` folder. Replace the old script 17.
3. From the **project root** RStudio Console run:

```r
source("scripts/19_fix_runtime_loader.R")
source("scripts/17_verify_deployment_bundle.R")
shiny::runApp("deployment/runtime")
```

Only the generated `deployment/runtime/app.R` is modified by script 19. Your root `app.R`, NHL data, synthetic data, saved models and Git repository are unchanged.

## To prevent the bug on future rebuilds

Copy the corrected `scripts/16_build_deployment_bundle.R` into the existing project's `scripts/` folder, replacing the old script 16. Future runs of script 16 will generate a runtime `app.R` whose three datasets are loaded directly using `readRDS("deploy_data/...")` rather than through conflicting loader function names. Script 17 now checks this explicitly.

## If errors persist

From the project root, run:

```r
file.exists("deployment/runtime/deploy_data/stage4a_reporting.rds")
file.exists("deployment/runtime/deploy_data/stage4b_reporting.rds")
file.exists("deployment/runtime/deploy_data/stage5b_reporting.rds")
```

All three must be TRUE. If any are FALSE, run corrected script 16 before script 17. If they are TRUE but launching fails, share the **new** error text, not any shinyapps.io tokens or GitHub credentials.

Do not publish until the optimized runtime launches locally and passes the functionality tests.
