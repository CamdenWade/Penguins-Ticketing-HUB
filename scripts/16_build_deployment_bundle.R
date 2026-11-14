# Stage 6B: build a self-contained, lighter Shiny runtime from validated local data.
# Run from Penguins-Ticketing-HUB project root.
# This does not modify app.R, existing RDS files, saved models or Git history.

stopifnot(file.exists("app.R"), dir.exists("R"), dir.exists("www"))
required_packages <- c("shiny", "bslib", "dplyr", "ggplot2", "scales", "DT")
missing_pkgs <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs)) stop("Install Shiny packages: ", paste(missing_pkgs, collapse=", "))

source("R/shiny_helpers.R")
source("R/shiny_data.R")
source("R/shiny_customer_data.R")
source("R/shiny_opportunity_helpers.R")
source("R/shiny_forecast_data.R")

message("Loading validated Stage 4A data and computing summary tables...")
hub <- load_stage4a_data()
message("Building synthetic customer reporting aggregates...")
crm <- load_stage4b_data(hub)
message("Loading Stage 5A historical backtest...")
forecast <- load_stage5b_data(hub)

stopifnot(nrow(hub$real) == 122L, nrow(hub$business) == 122L,
          nrow(hub$category) == 488L, nrow(hub$channel) == 366L,
          nrow(crm$cohorts) == 3L, nrow(forecast$predictions) == 40L,
          identical(forecast$selected_model, "historical_mean"),
          identical(crm$data_origin, "SYNTHETIC"))
stopifnot(sum(as.double(hub$business$sim_paid_tickets)) == 1970653,
          abs(sum(as.double(hub$business$sim_ticket_revenue_cents))/100 -
                (90776928 + 86359958 + 88820990)) < 3)

runtime <- "deployment/runtime"
dir.create(file.path(runtime, "R"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(runtime, "www"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(runtime, "deploy_data"), recursive = TRUE, showWarnings = FALSE)

app_lines <- readLines("app.R", warn = FALSE)
needle <- 'source("R/module_forecast.R")'
if (sum(trimws(app_lines) == needle) != 1L) {
  stop("Could not find the expected Stage 5B source anchor in app.R; do not patch automatically.", call. = FALSE)
}
idx <- which(trimws(app_lines) == needle)
# Shiny can load R/ files into the app environment automatically. Loader
# overrides sourced into another environment may then be shadowed. Avoid
# ambiguity: the DEPLOYMENT copy of app.R reads its three validated reporting
# snapshots explicitly, while the original development app.R is unchanged.
replacements <- c(
  'hub_data <- load_stage4a_data()' = 'hub_data <- readRDS("deploy_data/stage4a_reporting.rds")',
  'customer_data <- load_stage4b_data(hub_data)' = 'customer_data <- readRDS("deploy_data/stage4b_reporting.rds")',
  'forecast_data <- load_stage5b_data(hub_data)' = 'forecast_data <- readRDS("deploy_data/stage5b_reporting.rds")'
)
for (old in names(replacements)) {
  hits <- which(trimws(app_lines) == old)
  if (length(hits) != 1L) {
    stop("Expected exactly one app loader call: ", old,
         ". Verify that the working app.R is the Stage 5B version.", call. = FALSE)
  }
  app_lines[hits] <- unname(replacements[[old]])
}
# Keep deploy_loaders.R copied for compatibility with previous bundles, but do
# not rely on function name overrides to load deployment-only data.
app_lines <- append(app_lines, 'source("R/deploy_loaders.R")', after = idx)
writeLines(app_lines, file.path(runtime, "app.R"), useBytes = TRUE)

r_files <- c("shiny_helpers.R", "shiny_data.R", "module_attendance.R",
             "module_revenue.R", "shiny_customer_data.R", "module_customers.R",
             "shiny_opportunity_helpers.R", "shiny_forecast_data.R", "module_forecast.R")
css_files <- c("styles.css", "stage4b.css", "stage5b.css")
needed <- c(file.path("R", r_files), file.path("www", css_files), "R/deploy_loaders.R")
missing <- needed[!file.exists(needed)]
if (length(missing)) stop("Required app files missing: ", paste(missing, collapse=", "))
for (path in needed) {
  dst <- file.path(runtime, path)
  dir.create(dirname(dst), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(path, dst, overwrite = TRUE)) stop("Copy failed: ", path)
}

saveRDS(hub, file.path(runtime, "deploy_data/stage4a_reporting.rds"), compress = "gzip")
saveRDS(crm, file.path(runtime, "deploy_data/stage4b_reporting.rds"), compress = "gzip")
saveRDS(forecast, file.path(runtime, "deploy_data/stage5b_reporting.rds"), compress = "gzip")

# Runtime snapshot metadata; never include customer identities beyond synthetic IDs.
manifest <- data.frame(
  path = c("deploy_data/stage4a_reporting.rds", "deploy_data/stage4b_reporting.rds",
           "deploy_data/stage5b_reporting.rds"),
  source = c("REAL NHL + SYNTHETIC", "SYNTHETIC CRM", "REAL HISTORICAL BACKTEST"),
  stringsAsFactors = FALSE
)
manifest$bytes <- as.numeric(file.info(file.path(runtime, manifest$path))$size)
manifest$md5 <- unname(tools::md5sum(file.path(runtime, manifest$path)))
utils::write.csv(manifest, file.path(runtime, "deploy_data/manifest.csv"), row.names = FALSE)

message("PASS — Stage 6B runtime bundle built in: ", runtime)
message("Runtime reporting snapshot size: ", round(sum(manifest$bytes)/1024^2, 2), " MiB")
message("Next: source('scripts/17_verify_deployment_bundle.R')")
