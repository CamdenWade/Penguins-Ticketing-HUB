# Stage 4A — 90-second job fair demonstration

**Opening (15 seconds):** "I built an R Shiny sports business intelligence dashboard focused on Pittsburgh Penguins home games. I sourced and validated three completed seasons of real NHL attendance, then constructed a clearly identified synthetic ticketing and CRM environment for commercial analysis."

**Attendance tab (25 seconds):** Show the unfiltered 122 PPG Paints Arena games. Explain the total/average attendance and nominal capacity utilization. Change the season or opponent filter to show how the attendance trend and sortable game ledger respond. Mention the Stockholm designated-home-game exception and why venue-specific metrics exclude it.

**Revenue tab (25 seconds):** Switch tabs without resetting filters. Explain that *all* paid tickets, revenue, prices and categories are simulated. Point to weighted sell-through, revenue per paid ticket and seating mix. Explain the single upfront membership order with game-level earned revenue allocated once, avoiding double counting.

**Business interpretation (15 seconds):** "A ticketing department could use these kinds of views to identify games with lower engagement, evaluate seating inventory and segment revenue opportunities. The financial values are illustrative, not official team figures."

**Wrap-up (10 seconds):** "I developed the R data pipeline, integrity checks, relational synthetic datasets, Shiny modules and custom CSS theme. I'm extending the project with customer retention analysis and a defensible attendance forecasting model."

## Questions you may receive

**Why use synthetic ticket sales?** Transaction and CRM systems are confidential. Simulating internally consistent records lets me demonstrate analytics methods while honestly distinguishing public attendance from fictional business data.

**Why doesn't attendance equal tickets sold?** Reported attendance and paid ticket entitlements are different measures. Paid sales, comps, turnstile scans and other reconciliations can differ.

**Why can utilization exceed 100%?** It's an approximate reference metric using a published nominal capacity, not an audited event-by-event denominator.

**How did you avoid double counting membership revenue?** One season-level order per contract is allocated across eligible game rights. The game-level financial summaries use allocations and don't add the upfront purchase again.

**What is validated?** The user has passed 15 Stage 2 checks and 35 Stage 3 checks, including missing data, unique keys, inventory limits, matching IDs and exact financial reconciliation. The Stage 4A preflight verifies it can load and cross-check these outputs.

**One sensible improvement:** Add confidence intervals to opponent comparisons and more explicit source-by-source attendance spot checks before publishing a public case study.
