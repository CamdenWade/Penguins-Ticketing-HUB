# Stage 6B hotfix: patch ONLY the generated deployment/runtime/app.R.
# Safe to rerun. Does NOT touch the root app.R, RDS source files or models.
# Use after script 16 has already created the reporting snapshots.

runtime <- "deployment/runtime"
app_path <- file.path(runtime, "app.R")
snapshots <- c(
  "deploy_data/stage4a_reporting.rds",
  "deploy_data/stage4b_reporting.rds",
  "deploy_data/stage5b_reporting.rds"
)
if (!file.exists(app_path)) {
  stop("Deployment app missing. Run script 16 first.", call. = FALSE)
}
missing <- snapshots[!file.exists(file.path(runtime, snapshots))]
if (length(missing)) {
  stop("Optimized reporting snapshot(s) missing: ",
       paste(missing, collapse = ", "), ". Run script 16 first.", call. = FALSE)
}

app_lines <- readLines(app_path, warn = FALSE)
replacements <- c(
  'hub_data <- load_stage4a_data()' = 'hub_data <- readRDS("deploy_data/stage4a_reporting.rds")',
  'customer_data <- load_stage4b_data(hub_data)' = 'customer_data <- readRDS("deploy_data/stage4b_reporting.rds")',
  'forecast_data <- load_stage5b_data(hub_data)' = 'forecast_data <- readRDS("deploy_data/stage5b_reporting.rds")'
)

for (old in names(replacements)) {
  new <- unname(replacements[[old]])
  old_hits <- which(trimws(app_lines) == old)
  new_hits <- which(trimws(app_lines) == new)
  if (length(old_hits) == 1L && !length(new_hits)) {
    app_lines[old_hits] <- new
  } else if (!length(old_hits) && length(new_hits) == 1L) {
    # Already patched: rerunning this script is safe.
    next
  } else {
    stop("Unexpected app.R content for: ", old,
         ". No changes saved; inspect ", app_path, call. = FALSE)
  }
}

# Verify parseability before replacing the file.
validated <- tempfile(fileext = ".R")
writeLines(app_lines, validated, useBytes = TRUE)
tryCatch(parse(validated), error = function(e) {
  stop("Patched app.R failed to parse: ", conditionMessage(e), call. = FALSE)
})
writeLines(app_lines, app_path, useBytes = TRUE)
unlink(validated)
cat("PASS — deployment/runtime/app.R now loads only precomputed reporting snapshots.\n")
cat("Original root app.R, validated NHL data and synthetic records unchanged.\n")
cat("NEXT: source('scripts/17_verify_deployment_bundle.R')\n")
