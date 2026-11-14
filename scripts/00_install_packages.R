# Stage 2: install packages once, then restart R if requested.
required_packages <- c(
  "dplyr", "ggplot2", "httr2", "jsonlite", "lubridate",
  "readr", "rvest", "stringr", "tibble", "scales"
)
missing_packages <- setdiff(required_packages, rownames(installed.packages()))
if (length(missing_packages) > 0) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}
message("Stage 2 packages are available.")
