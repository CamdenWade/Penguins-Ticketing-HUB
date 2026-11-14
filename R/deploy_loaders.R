# Stage 6B: load deployment-only, locally validated reporting snapshots.
# The development app keeps using its original Stage 4/5 loader functions.
# Do not source this file outside the generated deployment/runtime app.
load_stage4a_data <- function() {
  path <- "deploy_data/stage4a_reporting.rds"
  if (!file.exists(path)) stop("Deployment reporting snapshot missing: ", path, call. = FALSE)
  readRDS(path)
}
load_stage4b_data <- function(stage4a) {
  path <- "deploy_data/stage4b_reporting.rds"
  if (!file.exists(path)) stop("Deployment customer snapshot missing: ", path, call. = FALSE)
  x <- readRDS(path)
  if (!identical(x$data_origin, "SYNTHETIC")) stop("Customer provenance mismatch", call. = FALSE)
  x
}
load_stage5b_data <- function(hub_data) {
  path <- "deploy_data/stage5b_reporting.rds"
  if (!file.exists(path)) stop("Deployment backtest snapshot missing: ", path, call. = FALSE)
  x <- readRDS(path)
  if (!identical(x$selected_model, "historical_mean")) stop("Model selection mismatch", call. = FALSE)
  x
}
