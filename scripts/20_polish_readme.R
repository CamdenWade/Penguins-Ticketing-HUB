# Penguins Ticketing HUB — final README polish
# Run from the project root. Edits README.md only; does not stage, commit, or push.
readme <- "README.md"
if (!file.exists(readme) || !file.exists("app.R")) {
  stop("Open Penguins-Ticketing-HUB.Rproj and run from the project root.", call. = FALSE)
}

lines <- readLines(readme, warn = FALSE, encoding = "UTF-8")
intro <- paste0(
  "An interactive sports business analytics portfolio project built to demonstrate ",
  "how a hockey organization's ticket sales, marketing, CRM, and business operations ",
  "teams could analyze demand, inventory, customer retention, and potential revenue opportunities."
)
impact <- paste0(
  "**Business impact:** Built to demonstrate how professional sports organizations ",
  "can use attendance analytics, ticketing KPIs, customer segmentation, and predictive ",
  "modeling to support revenue strategy, marketing decisions, and fan engagement."
)
outdated <- paste0(
  "**Status:** Local Shiny dashboards and data/model audits passed. ",
  "Public Shiny deployment is planned for Stage 6B; a live app URL has **not** ",
  "been published here yet."
)
old_tech <- "- **Git and GitHub** for source control; **shinyapps.io** deployment planned for Stage 6B"
new_tech <- "- **Git and GitHub** for version control; **shinyapps.io** for live cloud deployment"

if (!impact %in% lines && sum(lines == intro) != 1L)
  stop("Cannot uniquely locate the project introduction. No changes made.", call. = FALSE)
if (!old_tech %in% lines && !new_tech %in% lines)
  stop("Cannot locate the Tech stack bullet. No changes made.", call. = FALSE)
if (sum(lines == old_tech) > 1L || sum(lines == outdated) > 1L)
  stop("Unexpected duplicate sections. No changes made.", call. = FALSE)

# Add impact paragraph after the existing project introduction, just before the disclaimer.
if (!impact %in% lines) {
  i <- match(intro, lines)
  if (i < length(lines) && identical(lines[i + 1L], "")) {
    lines <- append(lines, c(impact, ""), after = i + 1L)
  } else {
    lines <- append(lines, c("", impact, ""), after = i)
  }
}

# Delete only the obsolete status paragraph, not the new deployed status.
lines <- lines[lines != outdated]
# Update the remaining tech-stack wording.
lines[lines == old_tech] <- new_tech
writeLines(lines, readme, useBytes = TRUE)

stopifnot(
  sum(lines == impact) == 1L,
  sum(lines == outdated) == 0L,
  sum(lines == new_tech) == 1L
)
cat("PASS — README.md updated with business impact, no outdated status, and live-deployment tech-stack wording.\n")
cat("No Git commit or push performed. Review README.md in RStudio, then use the Git tab to Commit and Push.\n")
