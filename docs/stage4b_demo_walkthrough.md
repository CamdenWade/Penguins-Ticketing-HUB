# Stage 4B — 90-second job fair demonstration

**Opening (0:00–0:15):** "This is an R Shiny ticketing and fan-revenue analytics hub. It separates real Penguins game attendance from a synthetic but internally consistent ticketing and customer database. None of the revenues or CRM records are official Penguins data."

**Attendance (0:15–0:30):** Show real attendance trends, an opponent filter, and the 122 PPG Paints Arena games across the last three completed seasons. Mention the Stockholm venue exception.

**Revenue (0:30–0:45):** Switch to simulated sales. Highlight ticket revenue, paid volume, channel mix and price-versus-volume questions. Note that membership revenue is allocated across games without double counting.

**Customer & Membership (0:45–1:15):** Show selected-game accounts and fan segments, then the full-season renewal/retention panels. Choose 2024–25 or 2025–26 to demonstrate eligible prior-year cohorts. Change an opponent filter to show game-level metrics change while full-season retention rates do not.

**Close (1:15–1:30):** "This demonstrates reproducible data acquisition, validation, relational data integration, accounting reconciliation, customer cohort logic and interactive reporting for ticketing and business operations. Next I'm adding an interpretable forecast trained only on real historical game features."

**Potential interviewer questions:**

- *Are these real ticket sales?* No. The only observed figures are game and attendance information from NHL reports. All purchases, CRM and financials are labeled synthetic.
- *Why does first-observed not mean new fan?* We only observe the artificial 2023–26 purchase window. Customers may have previous history outside the observation window in real-world applications.
- *Why don't opponent filters change renewal?* Eligibility requires full-season cohorts; restricting the denominator to a few games would create misleading rates.
- *How are memberships accounted for?* One purchase order per membership contract, with contract revenue allocated once over its eligible game entitlements.
- *What would make this production-ready?* Actual authorized CRM/turnstile/sales data, privacy controls, seat inventory integration, verified financial accounting policy, and model monitoring.
