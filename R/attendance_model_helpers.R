# Stage 5A — reusable, BASE-R attendance modeling helpers.
# Data source: validated NHL game-level records ONLY (Stage 2).
# Never source synthetic ticket sales, simulated CRM, game results, or
# reported attendance as a predictor.

ATTENDANCE_SEASONS <- c("2023-24", "2024-25", "2025-26")
ATTENDANCE_FEATURES <- c(
  "is_weekend", "is_friday", "is_metro_opponent",
  "month_sin", "month_cos", "home_game_progress",
  "days_since_previous_home", "is_home_opener"
)
ATTENDANCE_METRO_TEAMS <- c("CAR", "CBJ", "NJD", "NYI", "NYR", "PHI", "WSH")
ATTENDANCE_LAMBDAS <- c(0.02, 0.1, 0.5, 2, 10, 50)
ATTENDANCE_MIN_MAE_GAIN <- 50 # Predetermined guard against tiny validation gains

assert_columns <- function(data, columns, name = "data") {
  missing <- setdiff(columns, names(data))
  if (length(missing)) {
    stop(name, " missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

make_attendance_features <- function(real_games) {
  needed <- c("game_id", "season", "game_date", "opponent", "venue",
              "is_ppg_home", "reported_attendance", "data_origin")
  assert_columns(real_games, needed, "Stage 2 real NHL games")
  if (nrow(real_games) != 123L || anyNA(real_games$game_id) ||
      anyDuplicated(as.character(real_games$game_id)) ||
      anyNA(real_games$is_ppg_home) ||
      anyNA(real_games$data_origin) ||
      !all(real_games$data_origin == "REAL_NHL")) {
    stop("Unexpected counts, keys, venue flags, or provenance in real NHL data.", call. = FALSE)
  }

  g <- real_games[real_games$is_ppg_home, needed, drop = FALSE]
  g$game_id <- as.character(g$game_id)
  g$season <- as.character(g$season)
  g$game_date <- as.Date(g$game_date)
  g$opponent <- as.character(g$opponent)
  g$reported_attendance <- as.numeric(g$reported_attendance)
  counts <- table(factor(g$season, levels = ATTENDANCE_SEASONS))
  if (nrow(g) != 122L || !identical(as.integer(counts), c(41L, 41L, 40L)) ||
      anyNA(g$season) || !all(g$season %in% ATTENDANCE_SEASONS) ||
      anyNA(g$game_date) || anyNA(g$opponent) || any(!nzchar(g$opponent)) ||
      anyNA(g$reported_attendance) || any(!is.finite(g$reported_attendance)) ||
      any(g$reported_attendance <= 0)) {
    stop("Stage 2 attendance/venue/season validation failed.", call. = FALSE)
  }

  g <- g[order(match(g$season, ATTENDANCE_SEASONS), g$game_date, g$game_id), , drop = FALSE]
  rownames(g) <- NULL
  n <- nrow(g)
  game_number <- integer(n)
  previous_gap <- numeric(n)
  for (season in ATTENDANCE_SEASONS) {
    ix <- which(g$season == season)
    game_number[ix] <- seq_along(ix)
    previous_gap[ix] <- c(7, pmin(21, pmax(1, as.numeric(diff(g$game_date[ix])))))
  }

  # These are all available from the published schedule BEFORE each game.
  # Friday = 5; Saturday = 6; Sunday = 0 in POSIXlt$wday.
  weekday <- as.POSIXlt(g$game_date)$wday
  month <- as.integer(format(g$game_date, "%m"))
  g$home_game_number <- game_number
  g$calendar_month <- month
  g$is_weekend <- as.integer(weekday %in% c(0L, 6L))
  g$is_friday <- as.integer(weekday == 5L)
  g$is_metro_opponent <- as.integer(g$opponent %in% ATTENDANCE_METRO_TEAMS)
  g$month_sin <- sin(2 * pi * month / 12)
  g$month_cos <- cos(2 * pi * month / 12)
  g$home_game_progress <- (game_number - 1) / 40 # fixed scale, no target leakage
  g$days_since_previous_home <- previous_gap
  g$is_home_opener <- as.integer(game_number == 1L)

  assert_model_frame(g)
  g
}

assert_model_frame <- function(data) {
  assert_columns(data, c("game_id", "season", "game_date", "opponent",
                         "reported_attendance", "data_origin", ATTENDANCE_FEATURES),
                 "Attendance feature data")
  predictors <- as.matrix(data[, ATTENDANCE_FEATURES, drop = FALSE])
  if (!is.numeric(predictors) || anyNA(predictors) ||
      any(!is.finite(predictors)) || anyNA(data$reported_attendance) ||
      any(!is.finite(data$reported_attendance)) ||
      any(data$reported_attendance <= 0) ||
      !all(data$data_origin == "REAL_NHL")) {
    stop("Invalid or non-real NHL modeling inputs.", call. = FALSE)
  }
  invisible(TRUE)
}

fit_attendance_mean <- function(train) {
  assert_model_frame(train)
  list(model_type = "historical_mean", average = mean(train$reported_attendance),
       n_train = nrow(train), train_seasons = unique(as.character(train$season)))
}

fit_attendance_ridge <- function(train, lambda) {
  assert_model_frame(train)
  if (length(lambda) != 1L || !is.finite(lambda) || lambda <= 0) {
    stop("lambda must be one positive finite number", call. = FALSE)
  }
  x <- as.matrix(train[, ATTENDANCE_FEATURES, drop = FALSE])
  centers <- colMeans(x)
  spreads <- apply(x, 2, stats::sd)
  spreads[!is.finite(spreads) | spreads == 0] <- 1
  z <- sweep(sweep(x, 2, centers, "-"), 2, spreads, "/")
  y <- as.numeric(train$reported_attendance)
  y_center <- mean(y)
  n <- nrow(z)
  # Minimize average squared error + lambda * sum(standardized_beta^2).
  # Intercept is NOT penalized; all scaling is learned from training data.
  lhs <- crossprod(z) / n + diag(lambda, ncol(z))
  rhs <- crossprod(z, y - y_center) / n
  coefficients <- as.numeric(solve(lhs, rhs))
  names(coefficients) <- ATTENDANCE_FEATURES
  list(model_type = "ridge", average = y_center, beta = coefficients,
       centers = centers, spreads = spreads, lambda = lambda,
       feature_names = ATTENDANCE_FEATURES, n_train = nrow(train),
       train_seasons = unique(as.character(train$season)))
}

predict_attendance <- function(model, new_data) {
  if (identical(model$model_type, "historical_mean")) {
    return(rep(model$average, nrow(new_data)))
  }
  if (!identical(model$model_type, "ridge")) stop("Unknown model type.", call. = FALSE)
  assert_columns(new_data, model$feature_names, "Prediction data")
  x <- as.matrix(new_data[, model$feature_names, drop = FALSE])
  if (!is.numeric(x) || anyNA(x) || any(!is.finite(x))) {
    stop("Non-finite prediction features.", call. = FALSE)
  }
  z <- sweep(sweep(x, 2, model$centers, "-"), 2, model$spreads, "/")
  as.numeric(model$average + drop(z %*% model$beta))
}

attendance_metrics <- function(actual, predicted) {
  if (length(actual) != length(predicted) || !length(actual) ||
      anyNA(actual) || anyNA(predicted) ||
      any(!is.finite(actual)) || any(!is.finite(predicted))) {
    stop("Invalid or missing values in model evaluation.", call. = FALSE)
  }
  err <- predicted - actual
  data.frame(
    n_games = length(actual),
    mae = mean(abs(err)),
    rmse = sqrt(mean(err^2)),
    bias_pred_minus_actual = mean(err),
    median_abs_error = stats::median(abs(err)),
    stringsAsFactors = FALSE
  )
}

check_season_splits <- function(feature_data) {
  assert_model_frame(feature_data)
  train <- feature_data[feature_data$season == "2023-24", , drop = FALSE]
  validation <- feature_data[feature_data$season == "2024-25", , drop = FALSE]
  test <- feature_data[feature_data$season == "2025-26", , drop = FALSE]
  if (nrow(train) != 41L || nrow(validation) != 41L || nrow(test) != 40L ||
      anyDuplicated(feature_data$game_id) ||
      length(intersect(train$game_id, validation$game_id)) ||
      length(intersect(train$game_id, test$game_id)) ||
      length(intersect(validation$game_id, test$game_id)) ||
      max(train$game_date) >= min(validation$game_date) ||
      max(validation$game_date) >= min(test$game_date)) {
    stop("Time-based splits are missing, overlapped, or out of order.", call. = FALSE)
  }
  list(train = train, validation = validation, test = test)
}

write_model_csv <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(data, path, row.names = FALSE, na = "")
}
