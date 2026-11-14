# Stage 6A: Publication readiness and Git safety check.
# Run from the existing Penguins-Ticketing-HUB RStudio project root.
# This script READS files and writes only outputs/tables/stage6a_publication_audit.csv.
# It does not initialize Git, stage, commit, push, regenerate data, or deploy Shiny.

root_files <- c(
  "app.R", "Penguins-Ticketing-HUB.Rproj", "README.md", ".gitignore"
)
helpers <- c(
  "nhl_helpers.R", "synthetic_helpers.R", "shiny_data.R",
  "shiny_helpers.R", "module_attendance.R", "module_revenue.R",
  "shiny_customer_data.R", "module_customers.R",
  "attendance_model_helpers.R", "shiny_forecast_data.R",
  "shiny_opportunity_helpers.R", "module_forecast.R"
)
script_names <- c(
  "00_install_packages.R", "01_build_games_real.R",
  "02_validate_games_real.R", "03_preview_attendance.R",
  "04_build_synthetic_ticketing.R", "05_validate_synthetic_ticketing.R",
  "06_preview_synthetic_kpis.R", "07_install_shiny_packages.R",
  "08_check_shiny_inputs.R", "09_check_customer_inputs.R",
  "10_prepare_attendance_features.R", "11_train_attendance_models.R",
  "12_diagnose_attendance_models.R", "13_validate_attendance_models.R",
  "14_check_forecast_dashboard.R", "15_check_git_publication.R"
)
css_names <- c("styles.css", "stage4b.css", "stage5b.css")
screenshot_names <- c(
  "attendance-dashboard.png", "revenue-dashboard.png",
  "customer-dashboard.png", "backtest-dashboard.png",
  "opportunity-dashboard.png"
)
required_sources <- c(
  root_files,
  file.path("R", helpers),
  file.path("scripts", script_names),
  file.path("www", css_names),
  file.path("docs", screenshot_names) # intentionally overwritten below
)
required_sources <- c(
  setdiff(required_sources, file.path("docs", screenshot_names)),
  file.path("docs/screenshots", screenshot_names),
  "docs/data_sources_and_ethics.md",
  "docs/reproducibility.md",
  "docs/stage6a_publication_playbook.md",
  "docs/stage5a_model_card.md",
  "docs/stage5b_methodology.md"
)

# Files essential to running the currently-working local application.
required_runtime <- c(
  "data/processed/games_real.rds",
  "data/synthetic/customers.rds",
  "data/synthetic/memberships.rds",
  "data/synthetic/seat_inventory.rds",
  "data/synthetic/ticket_orders.rds",
  "data/synthetic/ticket_order_lines.rds",
  "data/synthetic/game_business_summary.rds",
  "models/attendance_model_bundle.rds",
  "models/attendance_selected_model.rds"
)

quality_reports <- c(
  "outputs/tables/data_quality_checks.csv",
  "outputs/tables/stage3_data_quality_checks.csv",
  "outputs/tables/stage4b_data_quality_checks.csv",
  "outputs/tables/stage5a_data_quality_checks.csv",
  "outputs/tables/stage5b_dashboard_checks.csv"
)

results <- data.frame(
  check = character(), status = character(), detail = character(),
  stringsAsFactors = FALSE
)
add_result <- function(name, ok, detail = "", pending = FALSE) {
  results <<- rbind(results, data.frame(
    check = name,
    status = if (pending) "PENDING" else if (isTRUE(ok)) "PASS" else "FAIL",
    detail = as.character(detail),
    stringsAsFactors = FALSE
  ))
}

add_result(
  "Working directory is project root",
  file.exists("app.R") && dir.exists("R") && dir.exists("scripts"),
  getwd()
)

missing_sources <- required_sources[!file.exists(required_sources)]
add_result(
  "Source, styles, docs, and screenshots present",
  length(missing_sources) == 0L,
  if (length(missing_sources)) paste(missing_sources, collapse = "; ") else
    paste(length(required_sources), "required files found")
)

missing_runtime <- required_runtime[!file.exists(required_runtime)]
add_result(
  "Local runtime RDS/model files remain available",
  length(missing_runtime) == 0L,
  if (length(missing_runtime)) paste(missing_runtime, collapse = "; ") else
    paste(length(required_runtime), "runtime files retained locally")
)

missing_reports <- quality_reports[!file.exists(quality_reports)]
add_result(
  "Historical validation reports remain available locally",
  length(missing_reports) == 0L,
  if (length(missing_reports)) paste(missing_reports, collapse = "; ") else
    paste(length(quality_reports), "audit reports found")
)

for (path in quality_reports[file.exists(quality_reports)]) {
  audit <- tryCatch(utils::read.csv(path, stringsAsFactors = FALSE),
                    error = function(e) NULL)
  valid <- !is.null(audit) && "passed" %in% names(audit) &&
    nrow(audit) > 0L && !anyNA(audit$passed) && all(audit$passed)
  add_result(
    paste("Audit all passed:", basename(path)),
    valid,
    if (is.null(audit)) "Could not read" else
      paste(if (valid) sum(audit$passed) else sum(audit$passed, na.rm = TRUE),
            "/", nrow(audit), "checks passed")
  )
}

# Confirm .gitignore covers representative data/secrets; never delete them.
git_available <- nzchar(Sys.which("git"))
git_initialized <- dir.exists(".git") || file.exists(".git")
add_result("Git CLI installed", git_available,
           if (git_available) Sys.which("git") else "Install Git / Xcode command line tools")
add_result("Git repository initialized", git_initialized,
           if (git_initialized) "Git metadata present" else
             "Run git init -b main after copying .gitignore", pending = !git_initialized)

if (git_available && git_initialized) {
  ignored_paths <- c(
    "data/raw/nhl_game_summaries/example.html",
    "data/processed/games_real.rds",
    "data/synthetic/ticket_orders.rds",
    "data/modeling/attendance_features.rds",
    "models/attendance_model_bundle.rds",
    "outputs/tables/stage6a_publication_audit.csv",
    "rsconnect/shinyapps.io/example/example.dcf",
    ".Renviron"
  )
  ignore_ok <- vapply(ignored_paths, function(path) {
    status <- suppressWarnings(tryCatch(system2(
      "git", c("check-ignore", "-q", "--", path),
      stdout = FALSE, stderr = FALSE
    ), error = function(e) 99L))
    identical(as.integer(status), 0L)
  }, logical(1))
  add_result("Sensitive/generated paths ignored by Git",
             all(ignore_ok),
             if (all(ignore_ok)) "All representative paths excluded" else
               paste(ignored_paths[!ignore_ok], collapse = "; "))

  indexed <- tryCatch(system2("git", "ls-files", stdout = TRUE, stderr = FALSE),
                      error = function(e) character())
  forbidden <- indexed[
    grepl("^(data/(raw|processed|synthetic|modeling)/|models/|outputs/|rsconnect/)", indexed) |
      grepl("(^|/)(\\.Renviron|\\.env)(\\.|$)|\\.(rds|RData|pem|key|p12|pfx)$",
            indexed, ignore.case = TRUE)
  ]
  add_result("No private/generated outputs tracked or staged",
             length(forbidden) == 0L,
             if (length(forbidden)) paste(forbidden, collapse = "; ") else
               "No excluded paths in git ls-files")
} else {
  add_result("Git ignore and tracking checks", TRUE,
             "Rerun after git init to activate Git-specific checks", pending = TRUE)
}

# Git status is not a substitute for reviewing the actual staged changes before pushing.
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)
output_path <- "outputs/tables/stage6a_publication_audit.csv"
utils::write.csv(results, output_path, row.names = FALSE)
print(results, row.names = FALSE, right = FALSE)

failed <- results$check[results$status == "FAIL"]
if (length(failed)) {
  stop("Stage 6A readiness FAILED: ", paste(failed, collapse = " | "),
       ". Review ", output_path, call. = FALSE)
}
if (any(results$status == "PENDING")) {
  message("Stage 6A source/data checks PASS; Git initialization or review still pending.")
} else {
  message("PASS — Stage 6A publication readiness checks passed.")
}
message("Audit saved to: ", output_path)
message("This script did not stage, commit, or publish anything.")
