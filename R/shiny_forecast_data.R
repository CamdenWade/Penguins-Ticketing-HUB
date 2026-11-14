# STAGE 5B — Load Stage 5A holdout backtest artifacts without refitting or
# modifying the selected model, source NHL data, or synthetic transactions.

load_stage5b_data <- function(hub_data) {
  paths <- c(
    predictions = "data/modeling/attendance_holdout_predictions.rds",
    bundle = "models/attendance_model_bundle.rds",
    model_audit = "outputs/tables/stage5a_data_quality_checks.csv",
    metrics = "outputs/tables/stage5a_holdout_metrics.csv",
    original = "data/processed/games_real.rds"
  )
  missing <- paths[!file.exists(paths)]
  if (length(missing)) {
    stop("Missing Stage 5A outputs; finish Stage 5A scripts 10–13 first:\n - ",
         paste(unname(missing), collapse = "\n - "), call. = FALSE)
  }

  predictions <- readRDS(paths[["predictions"]])
  bundle <- readRDS(paths[["bundle"]])
  audit <- utils::read.csv(paths[["model_audit"]], stringsAsFactors = FALSE)
  metrics <- utils::read.csv(paths[["metrics"]], stringsAsFactors = FALSE)

  if (nrow(audit) != 37L || !"passed" %in% names(audit) ||
      anyNA(audit$passed) || !all(audit$passed)) {
    stop("Stage 5A model audit must have 37 passing checks.", call. = FALSE)
  }
  needed <- c("game_id", "season", "game_date", "opponent", "actual_attendance",
              "predicted_historical_mean", "predicted_ridge", "predicted_selected",
              "selected_model", "absolute_error", "data_origin")
  absent <- setdiff(needed, names(predictions))
  if (length(absent)) stop("Holdout predictions missing: ", paste(absent, collapse = ", "))
  metric_cols <- c("model", "n_games", "mae", "rmse",
                   "bias_pred_minus_actual", "selected_on_validation")
  if (length(setdiff(metric_cols, names(metrics)))) {
    stop("Saved model metric columns have changed.", call. = FALSE)
  }
  if (nrow(predictions) != 40L || anyNA(predictions[, needed, drop = FALSE]) ||
      anyDuplicated(as.character(predictions$game_id)) ||
      !all(predictions$season == "2025-26") ||
      !all(predictions$data_origin == "REAL_NHL") ||
      !setequal(predictions$game_id, bundle$test_game_ids) ||
      length(intersect(bundle$test_game_ids, bundle$training_game_ids)) ||
      length(bundle$training_game_ids) != 82L ||
      !bundle$selected_model %in% c("historical_mean", "ridge") ||
      !all(predictions$selected_model == bundle$selected_model) ||
      !identical(unname(bundle$split_seasons), c("2023-24", "2024-25", "2025-26")) ||
      !identical(bundle$final_training_seasons, c("2023-24", "2024-25"))) {
    stop("Stage 5A held-out data provenance/splits/selection inconsistent.", call. = FALSE)
  }
  if (!identical(as.character(bundle$source_md5),
                 as.character(unname(tools::md5sum(paths[["original"]]))))) {
    stop("Historical source changed after Stage 5A: rerun its validation.", call. = FALSE)
  }

  real <- hub_data$real
  ix <- match(as.character(predictions$game_id), as.character(real$game_id))
  if (anyNA(ix) ||
      !all(as.character(real$season[ix]) == as.character(predictions$season)) ||
      !all(as.Date(real$game_date[ix]) == as.Date(predictions$game_date)) ||
      !all(as.character(real$opponent[ix]) == as.character(predictions$opponent)) ||
      !all(as.numeric(real$reported_attendance[ix]) ==
             as.numeric(predictions$actual_attendance))) {
    stop("Backtest actual attendance no longer agrees with NHL source.", call. = FALSE)
  }

  pred_columns <- c("actual_attendance", "predicted_historical_mean",
                    "predicted_ridge", "predicted_selected", "absolute_error")
  if (any(!is.finite(as.matrix(predictions[, pred_columns, drop = FALSE]))) ||
      any(abs(as.numeric(predictions$predicted_selected) -
                as.numeric(predictions[[paste0("predicted_", bundle$selected_model)]])) > 1e-6) ||
      any(abs(predictions$absolute_error -
                abs(predictions$actual_attendance - predictions$predicted_selected)) > 1e-6)) {
    stop("Backtest predictions and selected-model errors inconsistent.", call. = FALSE)
  }

  if (nrow(metrics) != 2L ||
      !setequal(metrics$model, c("historical_mean", "ridge")) ||
      anyNA(metrics[, metric_cols, drop = FALSE]) ||
      sum(metrics$selected_on_validation) != 1L ||
      metrics$model[metrics$selected_on_validation] != bundle$selected_model) {
    stop("Holdout metrics/selected model do not reconcile.", call. = FALSE)
  }
  for (model in c("historical_mean", "ridge")) {
    delta <- predictions[[paste0("predicted_", model)]] - predictions$actual_attendance
    m <- metrics[metrics$model == model, , drop = FALSE]
    if (m$n_games != 40L || abs(m$mae - mean(abs(delta))) > 1e-6 ||
        abs(m$rmse - sqrt(mean(delta^2))) > 1e-6 ||
        abs(m$bias_pred_minus_actual - mean(delta)) > 1e-6) {
      stop("Saved model metrics do not match game-level predictions: ", model, call. = FALSE)
    }
  }

  # The precommitted selection is fixed by 2024-25 validation; do not
  # automatically promote a model that happened to win on the test season.
  if (bundle$selected_model != "historical_mean") {
    stop("Unexpected selected model: Stage 5A preselected historical_mean. Check artifacts.",
         call. = FALSE)
  }
  predictions$game_date <- as.Date(predictions$game_date)
  predictions <- predictions[order(predictions$game_date, predictions$game_id), , drop = FALSE]
  list(predictions = predictions, metrics = metrics,
       selected_model = bundle$selected_model,
       validation_scores = bundle$validation_scores,
       model_source = "2025-26 OUT-OF-TIME HISTORICAL BACKTEST")
}
