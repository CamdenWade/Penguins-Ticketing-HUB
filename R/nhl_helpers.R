# Helper functions for NHL official schedules and game-summary reports.
# Source: https://api-web.nhle.com/v1/club-schedule-season/PIT/{season}
# Reports: https://www.nhl.com/scores/htmlreports/{season}/GS{six-digit game code}.HTM

scalar_chr <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_character_)
  if (is.list(x) && !is.null(x$default)) x <- x$default
  if (is.list(x)) return(NA_character_)
  if (length(x) == 0 || is.na(x[[1]])) return(NA_character_)
  as.character(x[[1]])
}

scalar_num <- function(x) {
  value <- scalar_chr(x)
  if (is.na(value)) return(NA_real_)
  suppressWarnings(as.numeric(value))
}

# Downloads successful responses to disk. Cached copies make repeat runs polite.
get_cached_file <- function(url, destination, refresh = FALSE) {
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  if (!refresh && file.exists(destination) && file.info(destination)$size > 0) {
    return(destination)
  }
  response <- httr2::request(url) |>
    httr2::req_user_agent("PenguinsTicketingAnalyticsHUB/0.1 (educational portfolio)") |>
    httr2::req_timeout(30) |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_perform()
  body <- httr2::resp_body_raw(response)
  if (length(body) == 0) stop("Empty response: ", url)
  writeBin(body, destination)
  destination
}

parse_schedule_game <- function(game, season_id) {
  game_id <- scalar_chr(game$id)
  home <- scalar_chr(game$homeTeam$abbrev)
  away <- scalar_chr(game$awayTeam$abbrev)
  venue <- scalar_chr(game$venue)
  date <- as.Date(scalar_chr(game$gameDate))
  score_home <- scalar_num(game$homeTeam$score)
  score_away <- scalar_num(game$awayTeam$score)

  tibble::tibble(
    game_id = game_id,
    season = paste0(substr(season_id, 1, 4), "-", substr(season_id, 7, 8)),
    season_id = season_id,
    game_date = date,
    home_team = home,
    away_team = away,
    opponent = away,
    venue = venue,
    is_neutral_site = isTRUE(game$neutralSite),
    game_state = scalar_chr(game$gameState),
    start_time_utc = scalar_chr(game$startTimeUTC),
    home_goals = score_home,
    away_goals = score_away,
    result = dplyr::case_when(
      is.na(score_home) | is.na(score_away) ~ NA_character_,
      score_home > score_away ~ "W",
      score_home < score_away ~ "L",
      TRUE ~ "TIE_CHECK"
    ),
    schedule_source_url = paste0(
      "https://api-web.nhle.com/v1/club-schedule-season/PIT/", season_id
    )
  )
}

report_url_for_game <- function(game_id, season_id) {
  # NHL game ID 2025020013 -> season 20252026 / GS020013.HTM
  game_number_code <- substr(game_id, 5, 10)
  paste0("https://www.nhl.com/scores/htmlreports/", season_id,
         "/GS", game_number_code, ".HTM")
}

parse_attendance_from_report <- function(html_file) {
  document <- rvest::read_html(html_file)
  body <- rvest::html_element(document, "body")
  if (inherits(body, "xml_missing")) return(NA_integer_)
  text <- rvest::html_text2(body)
  text <- stringr::str_replace_all(text, "\u00a0", " ")
  # NHL reports use wording such as "Attendance 16,107 at PPG Paints Arena".
  found <- stringr::str_match(
    text,
    stringr::regex("\\bAttendance\\s+([0-9][0-9,]*)\\s+at\\b",
                   ignore_case = TRUE)
  )
  if (is.na(found[1, 2])) return(NA_integer_)
  as.integer(gsub(",", "", found[1, 2], fixed = TRUE))
}

get_game_attendance <- function(game_id, season_id, refresh = FALSE) {
  url <- report_url_for_game(game_id, season_id)
  cache_path <- file.path("data", "raw", "nhl_game_summaries",
                          paste0("GS_", game_id, ".html"))
  tryCatch({
    get_cached_file(url, cache_path, refresh = refresh)
    attendance <- parse_attendance_from_report(cache_path)
    list(
      reported_attendance = attendance,
      attendance_status = if (is.na(attendance)) "not_found_in_report" else "parsed",
      report_source_url = url
    )
  }, error = function(e) {
    warning("Game ", game_id, ": ", conditionMessage(e), call. = FALSE)
    list(reported_attendance = NA_integer_,
         attendance_status = "request_or_parse_failed",
         report_source_url = url)
  })
}
