# Launch with Rscript scripts/run_dashboard.R or shiny::runApp("dashboard").
dashboard_directory <- if (file.exists("data.R") && file.exists("dashboard.R")) getwd() else file.path(getwd(), "dashboard")
dashboard_directory <- normalizePath(dashboard_directory, mustWork = TRUE)
project_directory <- dirname(dashboard_directory)
.libPaths(c(file.path(project_directory, ".R-library"), .Library), include.site = FALSE)
if (!requireNamespace("shiny", quietly = TRUE) || !requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Run Rscript scripts/install_dashboard.R to install dashboard dependencies.")
}
library(shiny)
source(file.path(dashboard_directory, "data.R"), local = TRUE)
source(file.path(dashboard_directory, "plots.R"), local = TRUE)
source(file.path(dashboard_directory, "dashboard.R"), local = TRUE)
results_directory <- Sys.getenv("ATAC_RESULTS_DIR", unset = file.path(project_directory, "results", "dashboard"))
shinyApp(ui = atac_ui(), server = atac_server(results_directory))
