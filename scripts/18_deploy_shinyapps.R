# Stage 6B: deploy ONLY the self-contained runtime folder.
# Run after scripts 16 and 17, and after manually testing the runtime app.
# Authentication: use shinyapps.io Dashboard -> Account -> Tokens -> Show ->
# 'Show Secret' -> copy the suggested rsconnect::setAccountInfo(...) command
# into your LOCAL RStudio console (never into a script, Git or chat).

if (!requireNamespace("rsconnect", quietly=TRUE)) {
  stop("Run install.packages('rsconnect') first.")
}
if (!dir.exists("deployment/runtime")) stop("Build deployment/runtime first")
source("scripts/17_verify_deployment_bundle.R")
accounts <- rsconnect::accounts(server="shinyapps.io")
if (nrow(accounts) == 0L) {
  stop("No shinyapps.io account configured. Add your token in the local RStudio Console first.")
}
cat("Configured shinyapps.io accounts:\n")
print(accounts[, intersect(c("name", "server"), names(accounts)), drop=FALSE], row.names=FALSE)

# Set the account if more than one is configured. Keeping explicit selection avoids
# accidentally deploying to the wrong account.
account_name <- "camden-wade"

rsconnect::deployApp(
  appDir = normalizePath("deployment/runtime"),
  appName = "penguins-ticketing-hub",
  account = account_name,
  server = "shinyapps.io",
  appTitle = "Penguins Ticketing & Fan Revenue Analytics HUB",
  launch.browser = TRUE,
  forceUpdate = TRUE
)
