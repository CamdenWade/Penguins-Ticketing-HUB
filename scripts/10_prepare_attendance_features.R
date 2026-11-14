# Stage 5A, Step 1 — acquire NO new data; derive pregame features from Stage 2.
# Run from your existing Penguins-Ticketing-HUB.Rproj working directory.
source("R/attendance_model_helpers.R")

source_path <- "data/processed/games_real.rds"
if (!file.exists(source_path)) {
  stop("Missing validated Stage 2 source: ", source_path, call. = FALSE)
}
real_games <- readRDS(source_path)
features <- make_attendance_features(real_games)
source_md5 <- unname(tools::md5sum(source_path))
attr(features, "nhl_source_md5") <- source_md5

splits <- check_season_splits(features)
dir.create("data/modeling", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)

saveRDS(features, "data/modeling/attendance_features.rds")
write_model_csv(features, "data/modeling/attendance_features.csv")

feature_audit <- data.frame(
  season = ATTENDANCE_SEASONS,
  ppg_games = c(nrow(splits$train), nrow(splits$validation), nrow(splits$test)),
  purpose = c("Candidate training", "Candidate tuning / selection", "Untouched final test"),
  origin = "REAL_NHL",
  stringsAsFactors = FALSE
)
write_model_csv(feature_audit, "outputs/tables/stage5a_split_audit.csv")

cat("PASS — attendance features prepared from REAL NHL games only.\n")
print(feature_audit, row.names = FALSE)
cat("Predictors (pregame only): ", paste(ATTENDANCE_FEATURES, collapse = ", "), "\n", sep = "")
cat("Source MD5: ", source_md5, "\n", sep = "")
cat("Next: source('scripts/11_train_attendance_models.R')\n")
