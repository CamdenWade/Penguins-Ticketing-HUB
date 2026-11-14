# Stage 5A feature dictionary and leakage safeguards

## Observation level

One PPG Paints Arena regular-season game (`game_id`), uniquely linked back to `data/processed/games_real.rds`. All 122 observations are **REAL NHL**, not synthetic ticket transactions.

| Field | Type | Role | Interpretation |
|---|---|---|---|
| `game_id` | character | Identifier | NHL game identifier; never used as predictive input |
| `season` | character | Temporal split | One of 2023–24 / 2024–25 / 2025–26; **not** a predictor |
| `game_date` | Date | Time + feature source | Official scheduled date; **not** directly used as predictor |
| `opponent` | character | Reporting + feature source | Visiting team abbreviation; raw string **not** directly used as predictor |
| `reported_attendance` | numeric | **TARGET** | Official published attendance; never fed back into model predictors |
| `home_game_number` | integer | Reporting + feature source | Sequential PPG home game within season; not directly used as predictor |
| `calendar_month` | integer | Reporting + feature source | Local month number; transformed to cyclical calendar features |
| `is_weekend` | 0/1 | Predictor | Saturday or Sunday game |
| `is_friday` | 0/1 | Predictor | Friday game |
| `is_metro_opponent` | 0/1 | Predictor | Opponent among CAR, CBJ, NJD, NYI, NYR, PHI, WSH; division-context heuristic |
| `month_sin` | numeric | Predictor | Sine of month angle, predetermined cyclic transform |
| `month_cos` | numeric | Predictor | Cosine of month angle, predetermined cyclic transform |
| `home_game_progress` | numeric | Predictor | (PPG home-game number - 1) / 40; fixed season scale |
| `days_since_previous_home` | numeric | Predictor | Days since prior PPG home game, capped at 21; first home game encoded 7 |
| `is_home_opener` | 0/1 | Predictor | First PPG home game of the season |
| `venue` | character | Provenance/validation | Existing PPG game flag used to exclude Stockholm; not a predictor |
| `data_origin` | character | Provenance | Must be `REAL_NHL` |

Notes:

- The 40 denominator in `home_game_progress` is fixed for all seasons to avoid estimating a scale from future attendance outcomes. Schedule order is known pregame.
- `days_since_previous_home` is a **home-schedule cadence** feature, not team rest/travel information. The 7-day opener placeholder is paired with `is_home_opener`.
- No test outcomes enter scaling, tuning, or fitting.
- Feature engineering computes each game position only from the schedule within its respective season, not from a future attendance value. The completed published schedule is assumed available for a pre-season forecasting use case.
- If the user later applies this to partially completed future seasons, schedule-game cancellations/rescheduling and opponent-alias changes will need handling.

## Fields explicitly forbidden from the predictor matrix

`reported_attendance`, `nominal_utilization`, `home_goals`, `away_goals`, `result`, `attendance_status`, `attendance_origin`, `sim_paid_tickets`, `sim_ticket_revenue_cents`, `order_total_cents`, `customer_id`, `membership_id`, revenue, sell-through, reported utilization or any variable computed from the game attendance target.

## Model outputs

`stage5a_holdout_predictions.csv` contains: source game identifiers/dates/opponents, the official attendance **as an evaluation label**, separate predictions for baseline and ridge, the selected prediction, signed and absolute errors, and `data_origin=REAL_NHL`.

**Remember:** These are historical holdout predictions. They are **not** forecasts of actual Penguins ticket sales or revenues.
