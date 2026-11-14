# Stage 4B — KPI and Cohort Definitions

Every metric in the Customer & Membership tab is **SYNTHETIC**, including the account IDs, profiles, contracts, purchases, line-item revenue and customer segments.

## Selected games (all three global filters apply)

| KPI | Numerator | Denominator / logic |
|---|---|---|
| Accounts with tickets | Distinct synthetic `customer_id` | Any line entitlement on selected PPG games; distinct across the selection |
| Earned revenue per account | Sum of selected `net_revenue_cents` / 100 | Distinct selected accounts |
| Paid tickets per account | Sum of selected line `quantity` | Distinct selected accounts |
| Multi-game account share | Accounts with lines on at least 2 distinct selected `game_id` | Distinct selected accounts |
| Revenue by fan segment | Sum of allocated line `net_revenue_cents` by segment | Groups keyed by `customers$fan_segment` |
| Games represented per account | Distinct `game_id` with at least one paid entitlement | Distribution across selected accounts |

These are entitlements and hypothetical transactions, **not a measure of actual attendance**. An individual can hold multiple seats on the same game. Revenue is recorded by game and allocated ONCE for each membership right.

## Full-season cohorts (only global season filter applies)

| KPI | Definition |
|---|---|
| Membership renewal rate | Number of previous season's members also purchasing a membership in current season / distinct members from the immediately previous season |
| Purchaser retention rate | Distinct prior season purchasing accounts also purchasing in current season / distinct prior season purchasing accounts |
| First-observed purchasing account | Current season customer with no purchase in any previously observed season |
| Retained purchaser | Current season customer who purchased in immediately previous season |
| Reactivated purchaser | Current season customer who purchased in an earlier observed season but not in immediately previous season |
| Orders per active account-season | Number of distinct synthetic order headers / distinct active customer-season pairs for selected season(s) |

2023–24 is the first observed season: retention and renewal are undefined because we have no 2022–23 data. **Do not display 0%.**

When all three seasons are selected, renewal and retention cards are **eligible-cohort weighted ratios** across the two eligible year-to-year transitions (not means of percentages). Purchaser statuses are first-observed / retained / reactivated **within this synthetic window**.

Season-ticket membership is a single order header per contract per year, even though that contract produces an allocated game right for each eligible PPG home game. The frequency visualization counts the upfront membership contract once.

## Data lineage

- `data/synthetic/customers.rds`: anonymous customer IDs, fan segments.
- `data/synthetic/memberships.rds`: member contract histories and renewal flags.
- `data/synthetic/ticket_orders.rds`: single purchase-order header per payment.
- `data/synthetic/ticket_order_lines.rds`: game-level rights and allocated revenue.
- `data/processed/games_real.rds`: genuine reported NHL game attributes, used ONLY to define eligible home games and dates.

The Stage 3 simulation used attendance in demand calibration. These synthetic customer outcomes should **not** be used as exogenous features in a model predicting historical reported NHL attendance.
