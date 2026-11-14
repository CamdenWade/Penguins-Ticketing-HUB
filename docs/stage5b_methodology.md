# Stage 5B — Model and Scenario Methodology

## Data boundary

| View | Source | Status |
|---|---|---|
| Reported game attendance | Official NHL game reports, curated in Stage 2 | Historical real observation |
| Historical mean / ridge prediction | Stage 5A fitted models | Estimated attendance, **backtest only** |
| Historical accuracy metrics | 2025–26 held-out real attendance compared to model estimates | Historical evaluation |
| Sellable seats, paid tickets and revenue | Stage 3 reproducible simulation | **Synthetic** |
| Incremental sales, assumed price, marketing acquisition cost | Dashboard user inputs | Hypothetical what-if assumptions |

## Fixed preselected model

- Fit candidates initially on 41 games from 2023–24.
- Use 41 games from 2024–25 to choose ridge lambda and compare to historical mean.
- Require a **minimum 50-attendee MAE gain** to promote ridge over the mean.
- Best ridge (lambda = 0.5) improved validation MAE from 1,416.0 to 1,387.4 — only **28.6** attendees. So **historical mean was selected**.
- Refit candidates on 82 development games, evaluate both on the 40 held-out 2025–26 PPG Paints Arena games.
- On the final test, mean MAE = 1,172.616 and ridge MAE = 1,128.597. **Do not promote ridge based on test outcome.**
- In the dashboard, the MAE/RMSE cards are **fixed full-test scores**, even if game filters narrow the displayed historical rows. This avoids mislabeling filtered results as the full out-of-time evaluation.

No simulated data or postgame game result is a modeling predictor. These are not future-game forecasts. A deployment claiming predictive accuracy on future NHL seasons would require more seasons, truly prospective tests and data quality monitoring.

## Revenue opportunity formulas

For each selected game `g`:

```text
Available synthetic seats_g = Sellable inventory_g - Existing synthetic paid tickets_g
Extra synthetic tickets_g = floor(Available synthetic seats_g * Capture share)
Added gross revenue_g (cents) = Extra synthetic tickets_g * Assumed net extra-ticket price (cents)
Hypothetical marketing spend_g (cents) = Extra synthetic tickets_g * Assumed acquisition cost per extra ticket (cents)
Difference_g (cents) = Added gross revenue_g - Hypothetical marketing spend_g
Scenario sell-through = sum(Existing paid tickets_g + Extra tickets_g) / sum(Sellable seats_g)
```

- The sliders assume 0–100% conversion, $20–$300 assumed net price per added ticket and $0–$100 acquisition cost per added ticket.
- `floor()` rounds down **at the per-game level**, so the simulator does not create fractional tickets or exceed hypothetical inventory.
- The base and incremental revenue are from **synthetic** data and assumptions; no public or official Penguins sales figures are inferred.
- A seat being unsold in the synthetic simulation is not evidence that a real paying buyer exists. The model does **not** predict conversion, demand, elasticity, marketing returns, or the actual ticket price required to sell it.
- The difference after marketing expense is *not profit*; it excludes all other costs and any price displacement or cancellations.
- Scenario outputs recalculate on global season/opponent/weekday filters. The real-attendance model is not used to determine or justify incremental ticket conversion.

## Provenance and review

Input sources are checked at app launch; saved predictions must match original real NHL attendance and holdout evaluation metrics, and Stage 5A's 37 checks must pass. New Stage 5B validation reports are written to `outputs/tables/stage5b_dashboard_checks.csv`. The files in `data/processed`, `data/synthetic` and `models` are not modified by Stage 5B.
