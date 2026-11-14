# Stage 6B: verify locally built runtime directory before shinyapps.io upload.
# Does not deploy or modify the original data/model artifacts.
runtime <- "deployment/runtime"
need <- c("app.R", "R/shiny_helpers.R", "R/shiny_data.R", "R/module_attendance.R",
          "R/module_revenue.R", "R/shiny_customer_data.R", "R/module_customers.R",
          "R/shiny_opportunity_helpers.R", "R/shiny_forecast_data.R",
          "R/module_forecast.R", "R/deploy_loaders.R", "www/styles.css",
          "www/stage4b.css", "www/stage5b.css",
          "deploy_data/stage4a_reporting.rds", "deploy_data/stage4b_reporting.rds",
          "deploy_data/stage5b_reporting.rds", "deploy_data/manifest.csv")
abs <- file.path(runtime, need)
if (any(!file.exists(abs))) stop("Deployment bundle missing: ", paste(need[!file.exists(abs)], collapse=", "))
for (f in c("app.R", file.path("R", c("shiny_helpers.R", "shiny_data.R", "module_attendance.R",
                     "module_revenue.R", "shiny_customer_data.R", "module_customers.R",
                     "shiny_opportunity_helpers.R", "shiny_forecast_data.R",
                     "module_forecast.R", "deploy_loaders.R")))) {
  tryCatch(parse(file.path(runtime, f)), error = function(e) stop("R parse failed for ", f, ": ", conditionMessage(e)))
}

# Stage 6B loader regression guard: syntax-only checks can pass even if the
# runtime still calls the raw-data development loaders. Check the actual app.
app_source <- trimws(readLines(file.path(runtime, "app.R"), warn = FALSE))
required_snapshots <- c(
  'hub_data <- readRDS("deploy_data/stage4a_reporting.rds")',
  'customer_data <- readRDS("deploy_data/stage4b_reporting.rds")',
  'forecast_data <- readRDS("deploy_data/stage5b_reporting.rds")'
)
if (!all(required_snapshots %in% app_source)) {
  stop("Runtime app.R is still using development loaders. Run ",
       "source('scripts/19_fix_runtime_loader.R') or rebuild with ",
       "the corrected script 16.", call. = FALSE)
}

manifest <- utils::read.csv(file.path(runtime, "deploy_data/manifest.csv"), stringsAsFactors=FALSE)
if (nrow(manifest) != 3L || !setequal(manifest$path, need[grepl("\\.rds$", need)])) stop("Invalid snapshot manifest")
actual_md5 <- unname(tools::md5sum(file.path(runtime, manifest$path)))
if (!identical(as.character(actual_md5), as.character(manifest$md5))) stop("Snapshot checksum mismatch")
hub <- readRDS(file.path(runtime, "deploy_data/stage4a_reporting.rds"))
crm <- readRDS(file.path(runtime, "deploy_data/stage4b_reporting.rds"))
forecast <- readRDS(file.path(runtime, "deploy_data/stage5b_reporting.rds"))
stopifnot(nrow(hub$real) == 122L, nrow(hub$business) == 122L,
          nrow(hub$category) == 488L, nrow(hub$channel) == 366L,
          nrow(crm$cohorts) == 3L, nrow(forecast$predictions) == 40L,
          identical(crm$data_origin, "SYNTHETIC"),
          identical(forecast$selected_model, "historical_mean"))
if (anyNA(hub$real$reported_attendance) ||
    !all(hub$business$financial_data_origin == "SYNTHETIC")) stop("Data provenance failure")
source(file.path(runtime, "R/shiny_opportunity_helpers.R"), local=TRUE)
scenario <- calculate_ticket_opportunity(hub$business, 15, 90, 10)
summary <- summarize_ticket_opportunity(scenario)
stopifnot(summary$games == 122L, summary$extra == 33041L,
          summary$unsold == 220659L, summary$gross_revenue_usd == 2973690,
          summary$marketing_spend_usd == 330410)

# Check Git safety: data snapshots must never be staged or committed.
if (nzchar(Sys.which("git")) && dir.exists(".git")) {
  tracked <- suppressWarnings(system2("git", c("ls-files", "--", "deployment/runtime"), stdout=TRUE, stderr=FALSE))
  if (length(tracked)) stop("Deployment runtime contains tracked files. Untrack before publishing: ", paste(tracked, collapse=", "))
  status <- suppressWarnings(system2("git", c("check-ignore", "-q", "deployment/runtime/deploy_data/stage4a_reporting.rds"), stdout=FALSE, stderr=FALSE))
  if (!identical(as.integer(status), 0L)) stop(".gitignore does not protect deployment runtime snapshots")
}
cat("PASS — Stage 6B bundle verification. 122 games; 3 cohort seasons; 40 holdout games.\n")
cat("Default scenario: 33,041 extra synthetic tickets, $2,973,690 hypothetical revenue.\n")
cat("Total runtime directory size (MiB): ", round(sum(file.info(list.files(runtime, recursive=TRUE, full.names=TRUE))$size, na.rm=TRUE)/1024^2, 2), "\n")
cat("NEXT: shiny::runApp('deployment/runtime') to test locally.\n")
