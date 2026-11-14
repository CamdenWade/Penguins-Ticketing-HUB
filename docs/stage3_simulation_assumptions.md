# Stage 3 simulation assumptions and provenance

**Strict disclaimer:** This project is an independent educational simulation and not affiliated with or endorsed by the Pittsburgh Penguins or NHL. Except for game metadata and NHL-reported attendance from Stage 2, no figures are official or estimated official Penguins commercial performance.

## Inputs

- Actual: verified NHL game IDs, PPG venue flag, home game dates, reported attendance, and seasons from the validated Stage 2 RDS.
- Venue nominal reference: 18,187; purely illustrative split into four hypothetical categories summing to that reference.
- Categories/seat splits (synthetic): Upper Bowl 7,200; Lower Bowl 8,100; Center-Ice Club 1,800; Suites & Loges 1,087. The split is **not published official arena inventory**.
- Synthetic illustrative baseline per-seat list prices (2023–24 USD): $70 Upper, $145 Lower, $250 Club, $390 Suites & Loges.
- Synthetic member allocation prices (2023–24 per seat per game): $49, $100, $172, $260 respectively. Prices change by assumed ~3.5% per season and small seeded variation.
- Arena holds: random 0.6%–1.8% by game/category; those seats are excluded from sellable inventory.
- Synthetic CRM cohorts: 15,000, 10,000 and 10,000 new anonymous records for successive seasons. Not all accounts buy tickets.
- Initial membership contracts: 2,300; 500 and 550 new contracts in the following years, plus renewals from previous season. Retention probabilities vary by simulated segment.
- Each membership creates a **single purchase order** per season. Its payment is attributed to that season's eligible PPG home games in `ticket_order_lines`, so total order cash equals total game-attributed net revenue.
- Single-game orders: 1–5 tickets; group orders: 6–12 tickets; group pricing discounts and channel share are hypothetical.
- Synthetic paid demand is loosely correlated with **real reported attendance** via a demand-signal formula and includes additional random game/category variation. It is **not actual paid sales**; generated sale volumes do not exceed hypothetical sellable inventory. Paid sales are not set equal to attendance.
- The Stockholm game is not included in synthetic PPG inventory, sales, or membership entitlements. We do not assume actual Penguins membership arrangements for that event.
- Random number generator seed `261103` ensures repeatable output from the same input data and R version. Alter it in `R/synthetic_helpers.R` to produce an alternative scenario.

## Constraints and cautions

The synthetic data cannot establish actual pricing elasticity, marketing effectiveness, visitor demographics, Penguins customer churn, or true financial performance. Because observed attendance directly informs the generated ticket demand (and synthetic pricing), it is **leakage** to use simulated tickets sold or revenue as predictors of observed attendance. Forecasting should be limited to features that were genuinely knowable before each game.

There are no customer names, addresses, emails or personal financial details. Ticket values exclude taxes and fees and intentionally model *ticket* revenue only; do not present them as total arena or franchise revenue. The `fan_segment` is a simulation input, not empirically discovered clustering.
