# Stage 2 / Step 1: Download game schedules and official attendance.
# Run from the RStudio project root: source("scripts/01_build_games_real.R")

source("R/nhl_helpers.R")

required_packages <- c("dplyr", "httr2", "jsonlite", "lubridate",
                       "readr", "rvest", "stringr", "tibble")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace,
                                              logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop("Install packages first: ", paste(missing_packages, collapse = ", "))
}

# Set TRUE only when you want to download fresh copies instead of reusing caches.
REFRESH_DOWNLOADS <- FALSE
SEASON_IDS <- c("20232024", "20242025", "20252026")
REFERENCE_PPG_CAPACITY <- 18187L  # Published nominal capacity, not a game-specific count.

for (directory in c("data/raw/nhl_schedules", "data/raw/nhl_game_summaries",
                    "data/processed", "outputs/tables")) {
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
}

all_schedule_games <- list()
for (season_id in SEASON_IDS) {
  url <- paste0("https://api-web.nhle.com/v1/club-schedule-season/PIT/", season_id)
  cache_path <- file.path("data", "raw", "nhl_schedules",
                          paste0("PIT_", season_id, ".json"))
  message("Reading NHL schedule: ", season_id)
  get_cached_file(url, cache_path, refresh = REFRESH_DOWNLOADS)
  payload <- jsonlite::read_json(cache_path, simplifyVector = FALSE)
  if (is.null(payload$games) || length(payload$games) == 0) {
    stop("No schedule games found for ", season_id, ". Check the cached JSON.")
  }

  season_games <- lapply(payload$games, parse_schedule_game, season_id = season_id)
  season_df <- dplyr::bind_rows(season_games) |>
    dplyr::filter(.data$home_team == "PIT")
  # NHL game type 2 = regular season; second pair of game-ID digits = 02.
  season_df <- season_df |>
    dplyr::filter(substr(.data$game_id, 5, 6) == "02")
  if (nrow(season_df) == 0) stop("No PIT regular-season home games: ", season_id)
  message("  Designated regular-season home games: ", nrow(season_df))
  all_schedule_games[[season_id]] <- season_df
}

all_games <- dplyr::bind_rows(all_schedule_games) |>
  dplyr::arrange(.data$game_date, .data$game_id)

if (anyNA(all_games$game_id) || anyDuplicated(all_games$game_id)) {
  stop("Invalid or repeated game IDs in NHL schedule. Investigate before continuing.")
}

# Get attendance for each *designated home* game, including the Stockholm game.
attendance_results <- vector("list", nrow(all_games))
for (i in seq_len(nrow(all_games))) {
  message(sprintf("Attendance %03d/%03d: %s", i, nrow(all_games), all_games$game_id[i]))
  attendance_results[[i]] <- get_game_attendance(
    game_id = all_games$game_id[i],
    season_id = all_games$season_id[i],
    refresh = REFRESH_DOWNLOADS
  )
  # Avoid making back-to-back calls excessively quickly on the first download.
  if (i < nrow(all_games)) Sys.sleep(0.25)
}
attendance_df <- dplyr::bind_rows(attendance_results)

all_games <- dplyr::bind_cols(all_games, attendance_df) |>
  dplyr::mutate(
    is_ppg_home = !is.na(.data$venue) &
      stringr::str_detect(stringr::str_to_lower(.data$venue), "ppg paints arena"),
    nominal_capacity = dplyr::if_else(.data$is_ppg_home,
                                      REFERENCE_PPG_CAPACITY, NA_integer_),
    nominal_utilization = .data$reported_attendance / .data$nominal_capacity,
    day_of_week = as.character(lubridate::wday(.data$game_date,
                                               label = TRUE, week_start = 1)),
    is_weekend = lubridate::wday(.data$game_date, week_start = 1) >= 6,
    month = lubridate::month(.data$game_date),
    data_origin = "REAL_NHL",
    attendance_origin = "OFFICIAL_NHL_GAME_SUMMARY"
  ) |>
  dplyr::select(.data$game_id, .data$season, .data$season_id,
                .data$game_date, .data$day_of_week, .data$is_weekend,
                .data$month, .data$opponent, .data$home_team,
                .data$away_team, .data$venue, .data$is_neutral_site,
                .data$is_ppg_home, .data$reported_attendance,
                .data$nominal_capacity, .data$nominal_utilization,
                .data$home_goals, .data$away_goals, .data$result,
                .data$game_state, .data$start_time_utc,
                .data$attendance_status, .data$schedule_source_url,
                .data$report_source_url, .data$data_origin,
                .data$attendance_origin)

saveRDS(all_games, "data/processed/games_real_draft.rds")
readr::write_csv(all_games, "data/processed/games_real_draft.csv", na = "")
message("Saved DRAFT games: ", nrow(all_games), " rows")
message("Missing attendance: ", sum(is.na(all_games$reported_attendance)))
message("NEXT: source('scripts/02_validate_games_real.R')")
