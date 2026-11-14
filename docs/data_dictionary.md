# Stage 2 historical data dictionary

One row per regular-season game where Pittsburgh is the **designated home** team.

| Column | Type | Meaning |
|---|---|---|
| game_id | character | Unique NHL game ID |
| season | character | `2023-24`, `2024-25`, or `2025-26` |
| season_id | character | NHL eight-digit season code |
| game_date | Date | Venue-local game date from NHL schedule |
| opponent | character | Away-team abbreviation |
| venue | character | NHL-listed venue |
| is_neutral_site | logical | NHL schedule neutral-site flag |
| is_ppg_home | logical | Venue name matches PPG Paints Arena |
| reported_attendance | integer | Published attendance in official NHL game summary |
| nominal_capacity | integer | 18,187 reference for PPG games; NA otherwise |
| nominal_utilization | double | reported_attendance / nominal_capacity; may exceed 1 |
| result | character | W or L by final score |
| attendance_status | character | parsed / not_found_in_report / request_or_parse_failed |
| report_source_url | character | Official game-summary link |
| schedule_source_url | character | Official schedule API link |
| data_origin | character | REAL_NHL |
| attendance_origin | character | OFFICIAL_NHL_GAME_SUMMARY |

**Attendance is not tickets sold or turnstile scans.** No ticket revenue or customer-level information is inferred from this dataset.
