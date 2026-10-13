args <- commandArgs(trailingOnly = FALSE)
script <- sub("^--file=", "", args[grepl("^--file=", args)])
root <- if (length(script)) dirname(dirname(normalizePath(script))) else getwd()
.libPaths(c(file.path(root, ".R-library"), .Library), include.site = FALSE)
if (!requireNamespace("shiny", quietly = TRUE) || !requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Install dependencies first: Rscript scripts/install_dashboard.R", call. = FALSE)
}
port <- suppressWarnings(as.integer(Sys.getenv("ATAC_DASHBOARD_PORT", "3838")))
if (is.na(port) || port < 1L || port > 65535L) stop("ATAC_DASHBOARD_PORT must be a valid port.")
shiny::runApp(file.path(root, "dashboard"), host = "127.0.0.1", port = port,
              launch.browser = interactive())
