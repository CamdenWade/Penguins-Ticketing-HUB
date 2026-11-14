# STAGE 4A — Run once from the Penguins-Ticketing-HUB project root.
required_packages <- c("shiny", "bslib", "dplyr", "ggplot2", "scales", "DT")
missing_packages <- setdiff(required_packages, rownames(installed.packages()))
if (length(missing_packages)) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}
message("Stage 4A dependencies available: ", paste(required_packages, collapse = ", "))
