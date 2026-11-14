# Stage 5B — 90-second portfolio walk-through

**0:00–0:15 | Business context.** "I built a sports business intelligence app using real Pittsburgh Penguins attendance data and clearly labeled synthetic ticketing and CRM records. It is a portfolio simulation, not a Penguins internal system."

**0:15–0:35 | Historical forecasting discipline.** Open **Forecasting & Opportunities**. "For the attendance model, I used 2023–24 to train, 2024–25 to validate and 2025–26 as an untouched historical test. The historical mean met my predefined model-selection rule. Ridge happened to do slightly better on the test, but I did not change my selected model after seeing it."

**0:35–0:50 | Explain results.** "My selected model achieved approximately 1,173 attendees MAE per game across the 40 held-out games. This is a historical backtest — I am not presenting it as a live attendance forecast."

**0:50–1:15 | Inventory-limited ticket opportunity.** Move to the sliders. "A ticketing team could ask how a hypothetical promotion might convert some unsold seats. I model additional paid seats and incremental revenue without exceeding simulated inventory. The prices, conversion assumptions and campaign costs are synthetic."

**1:15–1:30 | Business usefulness and caveats.** "This demonstrates how I translate analysis into an operational decision interface. I make sure the model estimates and simulated revenue scenarios are distinguishable from reported NHL information. The next step with real team data would be backtesting demand, using actual transactions and testing pricing effects."

## Potential employer questions

**Why didn't you select ridge if it did better on the test?** Because selection was fixed on the validation season. Switching on final holdout evidence would bias the evaluation.

**Does your scenario predict $X of extra revenue?** No. It calculates what **would follow from user-entered hypothetical conversion and price assumptions** within simulated inventory, not whether buyers exist or will pay those prices.

**Are synthetic tickets the same as reported attendance?** No. Actual attendance refers to the NHL's reported game attendance. Ticket sales, ticket rights and pricing are different data-generating processes and are simulated here.

**What is a limitation?** Only 82 development games, 40 holdout games and a relatively sparse schedule-based feature set. The synthetic customer and revenue data are illustrative, not validated against a professional franchise's internal operations.
