# Stage 2 / Step 2: Audit and publish only complete, valid historical data.
# Run: source("scripts/02_validate_games_real.R")

required_packages <- c("dplyr", "readr", "tibble")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace,
                                              logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) stop("Missing packages: ", paste(missing_packages, collapse = ", "))

input <- "data/processed/games_real_draft.rds"
if (!file.exists(input)) stop("Draft data not found. Run scripts/01_build_games_real.R first.")
games <- readRDS(input)
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)

expected_seasons <- c("2023-24", "2024-25", "2025-26")
expected_counts <- c(41L, 41L, 41L)
expected_ppg <- c(41L, 41L, 40L)

season_audit <- games |>
  dplyr::group_by(.data$season) |>
  dplyr::summarise(
    home_games = dplyr::n(),
    ppg_games = sum(.data$is_ppg_home),
    non_ppg_games = sum(!.data$is_ppg_home),
    attendance_found = sum(!is.na(.data$reported_attendance)),
    attendance_missing = sum(is.na(.data$reported_attendance)),
    ppg_attendance_total = sum(.data$reported_attendance[.data$is_ppg_home], na.rm = TRUE),
    ppg_avg_attendance = mean(.data$reported_attendance[.data$is_ppg_home], na.rm = TRUE),
    .groups = "drop"
  )

venue_exceptions <- games |>
  dplyr::filter(!.data$is_ppg_home) |>
  dplyr::select(.data$game_id, .data$season, .data$game_date,
                .data$opponent, .data$venue, .data$reported_attendance)

missing_attendance <- games |>
  dplyr::filter(is.na(.data$reported_attendance)) |>
  dplyr::select(.data$game_id, .data$season, .data$game_date,
                .data$opponent, .data$attendance_status, .data$report_source_url)

# Rules: all 41 designated home games each season, all attendance found,
# 2025-26 Stockholm neutral-site home game, no duplicate IDs, valid outcomes.
checks <- tibble::tibble(check = character(), expected = character(),
                         actual = character(), passed = logical())
add_check <- function(name, expected, actual, passed) {
  checks <<- dplyr::bind_rows(checks, tibble::tibble(
    check = name, expected = as.character(expected),
    actual = as.character(actual), passed = isTRUE(passed)))
}

add_check("total home games", 123, nrow(games), nrow(games) == 123)
add_check("unique game IDs", 123, dplyr::n_distinct(games$game_id),
          !anyNA(games$game_id) && !anyDuplicated(games$game_id))
add_check("valid game dates", "all dates present", sum(!is.na(games$game_date)),
          all(!is.na(games$game_date)))
add_check("all PIT home", "123", sum(games$home_team == "PIT", na.rm = TRUE),
          all(!is.na(games$home_team) & games$home_team == "PIT"))
add_check("attendance missing", 0, nrow(missing_attendance), nrow(missing_attendance) == 0)
add_check("attendance positive", "all > 0", sum(games$reported_attendance > 0, na.rm = TRUE),
          all(!is.na(games$reported_attendance) & games$reported_attendance > 0))
add_check("scores available", "all scores available", sum(complete.cases(games[, c("home_goals", "away_goals")])),
          all(complete.cases(games[, c("home_goals", "away_goals")])))
add_check("no ties in final scores", 0, sum(games$result == "TIE_CHECK", na.rm = TRUE),
          !any(games$result == "TIE_CHECK", na.rm = TRUE))

for (i in seq_along(expected_seasons)) {
  s <- expected_seasons[i]
  actual_home <- sum(games$season == s, na.rm = TRUE)
  actual_ppg <- sum(games$season == s & games$is_ppg_home, na.rm = TRUE)
  add_check(paste0(s, " home count"), expected_counts[i], actual_home,
            actual_home == expected_counts[i])
  add_check(paste0(s, " PPG count"), expected_ppg[i], actual_ppg,
            actual_ppg == expected_ppg[i])
}

# Explicitly verify the 2025-11-16 Nashville home-designated game in Stockholm.
stockholm <- games |>
  dplyr::filter(.data$game_date == as.Date("2025-11-16"),
                .data$opponent == "NSH", .data$season == "2025-26")
stockholm_ok <- nrow(stockholm) == 1 &&
  !stockholm$is_ppg_home[1] &&
  grepl("Avicii", stockholm$venue[1], ignore.case = TRUE) &&
  isTRUE(stockholm$is_neutral_site[1])
add_check("Stockholm venue exception", "1 Avicii Arena non-PPG neutral-site game",
          if (nrow(stockholm) == 1) stockholm$venue[1] else nrow(stockholm),
          stockholm_ok)

readr::write_csv(season_audit, "outputs/tables/season_attendance_summary.csv")
readr::write_csv(venue_exceptions, "outputs/tables/venue_exceptions.csv")
readr::write_csv(missing_attendance, "outputs/tables/missing_attendance.csv")
readr::write_csv(checks, "outputs/tables/data_quality_checks.csv")

print(season_audit)
print(checks, n = Inf)

if (any(!checks$passed)) {
  stop("DATA QUALITY AUDIT FAILED. Inspect outputs/tables/data_quality_checks.csv and " ,
       "missing_attendance.csv. Do not publish the dataset until resolved.")
}

# Only validated datasets get the final, dashboard-facing filenames.
saveRDS(games, "data/processed/games_real.rds")
readr::write_csv(games, "data/processed/games_real.csv", na = "")
message("PASS: Stage 2 validated dataset written to data/processed/games_real.rds")
message("NEXT: source('scripts/03_preview_attendance.R')")
