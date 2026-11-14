# Stage 5A, Step 4 — independent audit of splits, provenance,
# prediction files, saved models, and reported evaluation scores.
source("R/attendance_model_helpers.R")

required_files <- c(
  "data/processed/games_real.rds",
  "data/modeling/attendance_features.rds",
  "models/attendance_model_bundle.rds",
  "models/attendance_selected_model.rds",
  "data/modeling/attendance_holdout_predictions.rds",
  "outputs/tables/stage5a_validation_model_scores.csv",
  "outputs/tables/stage5a_holdout_metrics.csv",
  "outputs/tables/stage5a_holdout_predictions.csv",
  "outputs/figures/stage5a_actual_vs_predicted.png",
  "outputs/figures/stage5a_accuracy_scatter.png",
  "outputs/figures/stage5a_residuals_by_game.png"
)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files)) {
  stop("Missing Stage 5A artifacts. Run scripts 10–12 first:\n - ",
       paste(missing_files, collapse = "\n - "), call. = FALSE)
}

real <- readRDS("data/processed/games_real.rds")
features <- readRDS("data/modeling/attendance_features.rds")
bundle <- readRDS("models/attendance_model_bundle.rds")
selected_saved <- readRDS("models/attendance_selected_model.rds")
pred <- readRDS("data/modeling/attendance_holdout_predictions.rds")
validation_scores <- utils::read.csv("outputs/tables/stage5a_validation_model_scores.csv")
holdout_metrics <- utils::read.csv("outputs/tables/stage5a_holdout_metrics.csv")
holdout_csv <- utils::read.csv("outputs/tables/stage5a_holdout_predictions.csv")

checks <- data.frame(check = character(), expected = character(),
                     actual = character(), passed = logical(),
                     stringsAsFactors = FALSE)
add_check <- function(name, expected, actual, passes) {
  checks <<- rbind(checks, data.frame(
    check = name, expected = as.character(expected),
    actual = as.character(actual),
    passed = isTRUE(passes), stringsAsFactors = FALSE
  ))
}

splits <- check_season_splits(features)
recomputed_features <- make_attendance_features(real)
matching_index <- match(as.character(features$game_id), as.character(real$game_id))

add_check("Only real NHL source rows", "REAL_NHL", paste(unique(features$data_origin), collapse = ";"),
          all(features$data_origin == "REAL_NHL"))
add_check("Original source count", 123, nrow(real), nrow(real) == 123L)
add_check("Model source count", 122, nrow(features), nrow(features) == 122L)
add_check("Season counts", "41,41,40", paste(vapply(splits, nrow, integer(1)), collapse = ","),
          identical(as.integer(vapply(splits, nrow, integer(1))), c(41L, 41L, 40L)))
add_check("Feature game IDs unique", 122, length(unique(features$game_id)),
          !anyNA(features$game_id) && !anyDuplicated(features$game_id))
add_check("No non-PPG game used", "all TRUE", sum(real$is_ppg_home[matching_index]),
          !anyNA(matching_index) && all(real$is_ppg_home[matching_index]))
add_check("Attendance source values preserved", "all equal", "compared by game_id",
          !anyNA(matching_index) &&
            isTRUE(all.equal(as.numeric(real$reported_attendance[matching_index]),
                             as.numeric(features$reported_attendance), tolerance = 0)))
add_check("Pregame feature set exact", "8 approved", length(bundle$feature_names),
          identical(bundle$feature_names, ATTENDANCE_FEATURES))
add_check("No post-game or synthetic predictors", "no leakage columns", "feature list checked",
          !any(grepl("attendance|goal|result|score|sim_|revenue|order|customer|ticket",
                     bundle$feature_names, ignore.case = TRUE)))
add_check("Pregame features reproducible", "exactly matches", "recomputed from Stage 2",
          isTRUE(all.equal(
            as.matrix(features[, ATTENDANCE_FEATURES, drop = FALSE]),
            as.matrix(recomputed_features[, ATTENDANCE_FEATURES, drop = FALSE]),
            tolerance = 1e-12, check.attributes = FALSE
          )))
add_check("Source RDS unchanged", "matching MD5", unname(tools::md5sum("data/processed/games_real.rds")),
          identical(as.character(bundle$source_md5),
                    as.character(unname(tools::md5sum("data/processed/games_real.rds")))))
add_check("Split boundaries fixed", "2023-24/2024-25/2025-26", paste(bundle$split_seasons, collapse = "/"),
          identical(unname(bundle$split_seasons), ATTENDANCE_SEASONS))
add_check("Final training only development seasons", "2023-24,2024-25",
          paste(bundle$final_training_seasons, collapse = ","),
          identical(bundle$final_training_seasons, ATTENDANCE_SEASONS[1:2]))
add_check("No test IDs in final training", 0,
          length(intersect(bundle$training_game_ids, bundle$test_game_ids)),
          !length(intersect(bundle$training_game_ids, bundle$test_game_ids)))
add_check("Final training count", 82, length(bundle$training_game_ids),
          length(bundle$training_game_ids) == 82L &&
            length(unique(bundle$training_game_ids)) == 82L &&
            all(vapply(bundle$models, function(x) x$n_train == 82L, logical(1))))
add_check("Test count", 40, nrow(pred),
          nrow(pred) == 40L && length(unique(pred$game_id)) == 40L)
add_check("Test season only", "2025-26", paste(unique(pred$season), collapse = ","),
          identical(unique(as.character(pred$season)), "2025-26"))
add_check("Test IDs match split", "40 matching", length(intersect(pred$game_id, splits$test$game_id)),
          setequal(pred$game_id, splits$test$game_id))
add_check("Actual test attendance unchanged", "exact match", "compared by game_id",
          isTRUE(all.equal(as.numeric(pred$actual_attendance),
                           as.numeric(splits$test$reported_attendance[match(pred$game_id, splits$test$game_id)]),
                           tolerance = 0)))
add_check("Holdout predictions finite", "all 40 x 3", "checked", all(is.finite(as.matrix(pred[, c(
          "predicted_historical_mean", "predicted_ridge", "predicted_selected"
        )]))))
add_check("Selected model predeclared", "historical_mean or ridge", bundle$selected_model,
          bundle$selected_model %in% c("historical_mean", "ridge"))
add_check("Selected model RDS matches bundle", "same saved fit", "compared",
          isTRUE(all.equal(selected_saved, bundle$models[[bundle$selected_model]], tolerance = 0)))
add_check("Ridge lambda from prespecified grid", "one grid value", bundle$selected_lambda,
          bundle$selected_lambda %in% ATTENDANCE_LAMBDAS)
add_check("Validation has 1 mean + 6 ridge rows", 7, nrow(validation_scores),
          nrow(validation_scores) == 7L &&
            sum(validation_scores$model == "historical_mean") == 1L &&
            sum(validation_scores$model == "ridge") == length(ATTENDANCE_LAMBDAS))

# Recompute selection from validation ONLY. This check has no access to test
# accuracy when deriving the selected model or ridge penalty.
ridge_val <- validation_scores[validation_scores$model == "ridge", , drop = FALSE]
ridge_best <- ridge_val[order(ridge_val$mae, ridge_val$rmse, ridge_val$lambda)[1], , drop = FALSE]
base_val <- validation_scores$mae[validation_scores$model == "historical_mean"][[1]]
expected_selected <- if (base_val - ridge_best$mae >= ATTENDANCE_MIN_MAE_GAIN) "ridge" else "historical_mean"
add_check("Model selection independent of test", expected_selected, bundle$selected_model,
          identical(bundle$selected_model, expected_selected))
add_check("Lambda selected by validation", ridge_best$lambda, bundle$selected_lambda,
          isTRUE(all.equal(bundle$selected_lambda, ridge_best$lambda, tolerance = 1e-12)))

idx <- match(pred$game_id, splits$test$game_id)
new_test <- splits$test[idx, , drop = FALSE]
base_recomputed <- predict_attendance(bundle$models$historical_mean, new_test)
ridge_recomputed <- predict_attendance(bundle$models$ridge, new_test)
selected_recomputed <- predict_attendance(bundle$models[[bundle$selected_model]], new_test)
add_check("Saved baseline predictions reproduce", "max difference < 1e-6",
          max(abs(base_recomputed - pred$predicted_historical_mean)),
          all(abs(base_recomputed - pred$predicted_historical_mean) < 1e-6))
add_check("Saved ridge predictions reproduce", "max difference < 1e-6",
          max(abs(ridge_recomputed - pred$predicted_ridge)),
          all(abs(ridge_recomputed - pred$predicted_ridge) < 1e-6))
add_check("Selected predictions reproduce", "max difference < 1e-6",
          max(abs(selected_recomputed - pred$predicted_selected)),
          all(abs(selected_recomputed - pred$predicted_selected) < 1e-6))
add_check("Residual signs correct", "actual minus predicted", "recomputed",
          all(abs(pred$residual_actual_minus_predicted -
                    (pred$actual_attendance - pred$predicted_selected)) < 1e-6))
add_check("CSV prediction row count", 40, nrow(holdout_csv), nrow(holdout_csv) == 40L)
add_check("Holdout metrics contain 2 models", "baseline and ridge",
          paste(sort(holdout_metrics$model), collapse = ","),
          setequal(holdout_metrics$model, c("historical_mean", "ridge")))

recomputed_base_metrics <- attendance_metrics(new_test$reported_attendance, base_recomputed)
recomputed_ridge_metrics <- attendance_metrics(new_test$reported_attendance, ridge_recomputed)
i_base <- match("historical_mean", holdout_metrics$model)
i_ridge <- match("ridge", holdout_metrics$model)
add_check("Baseline test MAE matches", "difference < 1e-6", "checked",
          abs(recomputed_base_metrics$mae - holdout_metrics$mae[i_base]) < 1e-6)
add_check("Ridge test MAE matches", "difference < 1e-6", "checked",
          abs(recomputed_ridge_metrics$mae - holdout_metrics$mae[i_ridge]) < 1e-6)
add_check("Baseline test RMSE matches", "difference < 1e-6", "checked",
          abs(recomputed_base_metrics$rmse - holdout_metrics$rmse[i_base]) < 1e-6)
add_check("Ridge test RMSE matches", "difference < 1e-6", "checked",
          abs(recomputed_ridge_metrics$rmse - holdout_metrics$rmse[i_ridge]) < 1e-6)
add_check("Only selected model flagged", "1", sum(holdout_metrics$selected_on_validation),
          sum(holdout_metrics$selected_on_validation) == 1L &&
            holdout_metrics$model[holdout_metrics$selected_on_validation] == bundle$selected_model)

write_model_csv(checks, "outputs/tables/stage5a_data_quality_checks.csv")
print(checks, row.names = FALSE, right = FALSE)
cat("\nStage 5A quality checks:", sum(checks$passed), "/", nrow(checks), "passed.\n")
if (any(!checks$passed)) {
  stop("STAGE 5A AUDIT FAILED. Inspect outputs/tables/stage5a_data_quality_checks.csv",
       call. = FALSE)
}
cat("PASS — Stage 5A attendance model is ready for review.\n")
cat("Selected on validation:", bundle$selected_model, "\n")
print(holdout_metrics, row.names = FALSE)
cat("IMPORTANT: This is a historical held-out backtest, not a future game forecast.\n")
