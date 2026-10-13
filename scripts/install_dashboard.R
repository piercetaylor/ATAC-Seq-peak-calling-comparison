# Install the small dashboard dependency set into this project.
args <- commandArgs(trailingOnly = FALSE)
script <- sub("^--file=", "", args[grepl("^--file=", args)])
root <- if (length(script)) dirname(dirname(normalizePath(script))) else getwd()
library_path <- file.path(root, ".R-library")
dir.create(library_path, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(library_path, .Library), include.site = FALSE)
packages <- c("shiny", "jsonlite")
options(timeout = max(600, getOption("timeout")))
package_type <- if (.Platform$OS.type == "windows") "binary" else "source"
# Freeze the dependency set to a tested R 4.4-era snapshot for reproducibility.
repository <- Sys.getenv("ATAC_R_REPOSITORY", "https://packagemanager.posit.co/cran/2025-06-01")
available <- available.packages(repos = repository, type = package_type)
if (!all(packages %in% rownames(available))) stop("Dashboard packages were not found in the configured repository.")
dependencies <- tools::package_dependencies(packages, db = available,
                                            which = c("Depends", "Imports", "LinkingTo"), recursive = TRUE)
required <- intersect(unique(c(packages, unlist(dependencies, use.names = FALSE))), rownames(available))
installed <- installed.packages(lib.loc = library_path)
missing <- required[!required %in% rownames(installed)]
present <- intersect(required, rownames(installed))
changed <- present[installed[present, "Version"] != available[present, "Version"]]
if (length(c(missing, changed))) {
  install.packages(c(missing, changed), lib = library_path, repos = repository, type = package_type)
}
stopifnot(all(vapply(packages, requireNamespace, logical(1), quietly = TRUE)))
versions <- installed.packages(lib.loc = library_path)
write.table(versions[intersect(required, rownames(versions)), c("Package", "Version"), drop = FALSE],
            file.path(library_path, "dashboard-package-versions.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)
cat("Dashboard dependencies are ready in", library_path, "\n")
