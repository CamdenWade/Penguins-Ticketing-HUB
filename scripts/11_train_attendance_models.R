# Stage 5A, Step 2 — choose model on 2024-25; test ONCE on 2025-26.
# This is an historical out-of-time BACKTEST, not live future predictions.
source("R/attendance_model_helpers.R")

input <- "data/modeling/attendance_features.rds"
if (!file.exists(input)) stop("Run Stage 5A script 10 first.", call. = FALSE)
features <- readRDS(input)
splits <- check_season_splits(features)
train <- splits$train
validation <- splits$validation
test <- splits$test

make_score_row <- function(name, lambda, actual, predicted) {
  cbind(data.frame(model = name, lambda = lambda, stringsAsFactors = FALSE),
        attendance_metrics(actual, predicted))
}

# 1) Determine lambda from the VALIDATION season only.
mean_train <- fit_attendance_mean(train)
val_scores <- list(make_score_row(
  "historical_mean", NA_real_, validation$reported_attendance,
  predict_attendance(mean_train, validation)
))
for (lambda in ATTENDANCE_LAMBDAS) {
  fit <- fit_attendance_ridge(train, lambda)
  val_scores[[length(val_scores) + 1L]] <- make_score_row(
    "ridge", lambda, validation$reported_attendance,
    predict_attendance(fit, validation)
  )
}
validation_scores <- do.call(rbind, val_scores)
rownames(validation_scores) <- NULL
ridge_rows <- validation_scores[validation_scores$model == "ridge", , drop = FALSE]
best_idx <- order(ridge_rows$mae, ridge_rows$rmse, ridge_rows$lambda)[1L]
best_ridge <- ridge_rows[best_idx, , drop = FALSE]
chosen_lambda <- best_ridge$lambda[[1L]]
mean_val_mae <- validation_scores$mae[validation_scores$model == "historical_mean"][[1L]]
ridge_val_mae <- best_ridge$mae[[1L]]

# A small gain on 41 validation games is not persuasive. Require 50 fans/game
# MAE reduction before promoting the ridge model over the simpler baseline.
selected_name <- if ((mean_val_mae - ridge_val_mae) >= ATTENDANCE_MIN_MAE_GAIN) {
  "ridge"
} else {
  "historical_mean"
}

# 2) Refit both on development seasons (2023-24 + 2024-25).
# There is still NO ACCESS to 2025-26 attendance outcomes in fitting.
development <- rbind(train, validation)
final_models <- list(
  historical_mean = fit_attendance_mean(development),
  ridge = fit_attendance_ridge(development, chosen_lambda)
)

# 3) Evaluate on the untouched 2025-26 test set, once.
pred_mean <- predict_attendance(final_models$historical_mean, test)
pred_ridge <- predict_attendance(final_models$ridge, test)
pred_selected <- if (selected_name == "ridge") pred_ridge else pred_mean

holdout_metrics <- rbind(
  cbind(data.frame(model = "historical_mean", stringsAsFactors = FALSE),
        attendance_metrics(test$reported_attendance, pred_mean)),
  cbind(data.frame(model = "ridge", stringsAsFactors = FALSE),
        attendance_metrics(test$reported_attendance, pred_ridge))
)
holdout_metrics$selected_on_validation <- holdout_metrics$model == selected_name

holdout_predictions <- data.frame(
  game_id = test$game_id,
  season = test$season,
  game_date = test$game_date,
  opponent = test$opponent,
  home_game_number = test$home_game_number,
  calendar_month = test$calendar_month,
  is_weekend = test$is_weekend,
  actual_attendance = test$reported_attendance,
  predicted_historical_mean = pred_mean,
  predicted_ridge = pred_ridge,
  predicted_selected = pred_selected,
  selected_model = selected_name,
  residual_actual_minus_predicted = test$reported_attendance - pred_selected,
  absolute_error = abs(test$reported_attendance - pred_selected),
  data_origin = "REAL_NHL",
  stringsAsFactors = FALSE
)

bundle <- list(
  source = "Validated real NHL Penguins PPG home-game attendance; NOT ticket sales",
  source_md5 = attr(features, "nhl_source_md5"),
  feature_names = ATTENDANCE_FEATURES,
  model_types = c("historical_mean", "ridge"),
  selected_model = selected_name,
  min_mae_gain_required = ATTENDANCE_MIN_MAE_GAIN,
  lambda_candidates = ATTENDANCE_LAMBDAS,
  selected_lambda = chosen_lambda,
  split_seasons = c(train = "2023-24", validation = "2024-25", test = "2025-26"),
  final_training_seasons = c("2023-24", "2024-25"),
  training_game_ids = development$game_id,
  test_game_ids = test$game_id,
  models = final_models,
  validation_scores = validation_scores,
  holdout_metrics = holdout_metrics,
  methodological_limitations = c(
    "Only 82 development games and 40 test games; estimates have considerable uncertainty.",
    "2025-26 is held out in time; this is historical backtesting, not a live forecast.",
    "Predictors are known pregame from schedule only; no score, attendance, or synthetic sales inputs.",
    "No capacity clipping. Reported attendance can exceed nominal reference seating capacity.",
    "Validation (2024-25), not test (2025-26), determines model and lambda."
  )
)

dir.create("models", recursive = TRUE, showWarnings = FALSE)
dir.create("data/modeling", recursive = TRUE, showWarnings = FALSE)
for (path in c("outputs/tables")) dir.create(path, recursive = TRUE, showWarnings = FALSE)
saveRDS(bundle, "models/attendance_model_bundle.rds")
saveRDS(final_models[[selected_name]], "models/attendance_selected_model.rds")
saveRDS(holdout_predictions, "data/modeling/attendance_holdout_predictions.rds")
write_model_csv(validation_scores, "outputs/tables/stage5a_validation_model_scores.csv")
write_model_csv(holdout_metrics, "outputs/tables/stage5a_holdout_metrics.csv")
write_model_csv(holdout_predictions, "outputs/tables/stage5a_holdout_predictions.csv")

cat("\nStage 5A — VALIDATION results (2024-25; tune/choose here):\n")
print(validation_scores, row.names = FALSE, digits = 5)
cat("Best ridge lambda:", chosen_lambda, "\n")
cat("Model selected BEFORE seeing test results:", selected_name, "\n")
cat("\nStage 5A — FINAL HOLDOUT results (2025-26; 40 games):\n")
print(holdout_metrics, row.names = FALSE, digits = 5)
cat("Next: source('scripts/12_diagnose_attendance_models.R')\n")
