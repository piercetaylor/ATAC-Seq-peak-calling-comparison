# Run: Rscript tests/test_dashboard.R. Fixtures are temporary and never copied to results/.
args <- commandArgs(trailingOnly = FALSE)
script <- sub("^--file=", "", args[grepl("^--file=", args)])
root <- if (length(script)) dirname(dirname(normalizePath(script))) else getwd()
.libPaths(c(file.path(root, ".R-library"), .Library), include.site = FALSE)
source(file.path(root, "dashboard", "data.R"))
fixture <- tempfile("atac-dashboard-test-")
dir.create(fixture)

check <- function(condition, message) {
  if (!isTRUE(condition)) stop(message, call. = FALSE)
  cat("PASS", message, "\n")
}
write_fixture <- function(name, data) {
  write.table(data, file.path(fixture, paste0(name, ".tsv")), sep = "\t", row.names = FALSE,
              quote = FALSE, na = "NA")
}
empty <- read_atac_results(fixture)
check(!empty$has_results && length(empty$samples) == 0 && length(empty$issues) == 0,
      "Missing output directory yields a clean empty state")
peaks <- data.frame(sample = c("RepA", "RepA", "RepB"), caller = c("MACS3", "Genrich", "MACS3"),
                    n_peaks = c(10, 12, 8), total_peak_bp = c(1000, 1200, 800),
                    median_peak_width = c(100, 90, NA), frip = c(.4, .5, NA), fragments = c(100, 100, 80))
write_fixture("peak_metrics", peaks)
loaded <- read_atac_results(fixture)
check(loaded$has_results && nrow(loaded$tables$peak_metrics) == 3 && is.na(loaded$tables$peak_metrics$frip[3]),
      "Valid metrics preserve missing observations and numeric columns")
check(any(grepl("metadata", loaded$status$status)), "Metrics without metadata do not imply a completed biological run")
subset <- filter_atac_table(loaded$tables$peak_metrics, "RepA", "Genrich")
check(nrow(subset) == 1 && subset$n_peaks == 12, "Sample and caller selections intersect")
check(nrow(filter_atac_table(peaks, character(), "MACS3")) == 0, "Empty selection stays empty")
findings <- atac_findings(list(
  replicate_overlap = data.frame(caller = c("MACS3", "Genrich"), jaccard = c(.6, .8)),
  pairwise_overlap = data.frame(sample = "RepA", caller_a = "MACS3", caller_b = "Genrich", jaccard = .5),
  peak_metrics = peaks, runtime = data.frame(sample = "RepA", caller = c("MACS3", "Genrich"), elapsed_seconds = c(600, 60))))
check(length(findings) == 4 && grepl("Genrich 0.80, MACS3 0.60", findings[1]) && grepl("fastest is Genrich", findings[4]),
      "Findings are derived from and ordered by the measured tables")
check(!length(atac_findings(lapply(atac_schemas, function(x) data.frame()))), "No tables yield no findings")

bad <- peaks
bad$frip[1] <- 1.2
write_fixture("peak_metrics", bad)
check(grepl("between 0 and 1", read_atac_results(fixture)$issues[1]), "Out-of-range fractions are withheld")
bad <- peaks
bad$n_peaks[1] <- "not numeric"
write_fixture("peak_metrics", bad)
check(grepl("numeric", read_atac_results(fixture)$issues[1]), "Malformed numeric values are withheld")
write_fixture("peak_metrics", peaks[c(1, 1), ])
check(grepl("duplicate", read_atac_results(fixture)$issues[1]), "Duplicate keys cannot silently inflate results")
write_fixture("peak_metrics", peaks[, -5])
check(grepl("missing columns", read_atac_results(fixture)$issues[1]), "Missing required columns are reported")
write_fixture("peak_metrics", peaks)

overlap <- data.frame(sample = "RepA", caller_a = "MACS3", caller_b = "Genrich", intersection_bp = 500,
                      union_bp = 1500, jaccard = 1/3)
write_fixture("pairwise_overlap", overlap)
matrix <- atac_overlap_matrix(overlap, c("MACS3", "Genrich", "HMMRATAC"))
check(identical(matrix[1, 2], matrix[2, 1]) && is.na(matrix[1, 1]) && is.na(matrix[1, 3]),
      "Overlap matrix is symmetric with missing comparisons left unmeasured")
overlap$jaccard <- .8
write_fixture("pairwise_overlap", overlap)
check(any(grepl("disagree", read_atac_results(fixture)$issues)), "Inconsistent Jaccard values are withheld")
overlap$jaccard <- 1/3
write_fixture("pairwise_overlap", overlap)
write_fixture("qc", data.frame(sample = "RepA", raw_pairs = 100, filtered_pairs = 101,
                                duplicate_fraction = .1, mitochondrial_fraction = .1))
check(any(grepl("exceed", read_atac_results(fixture)$issues)), "Impossible retained read counts are withheld")
write_fixture("qc", data.frame(sample = "RepA", raw_pairs = 100, filtered_pairs = 70,
                                duplicate_fraction = .1, mitochondrial_fraction = .1))
write_fixture("fragment_lengths", data.frame(sample = c("RepA", "RepA"), length_bp = c(100, 200), fragments = c(8, 2)))
check(nrow(read_atac_results(fixture)$tables$fragment_lengths) == 2,
      "Frequency distributions retain multiple bins per sample")

if (requireNamespace("shiny", quietly = TRUE) && requireNamespace("jsonlite", quietly = TRUE)) {
  library(shiny)
  source(file.path(root, "dashboard", "plots.R"))
  source(file.path(root, "dashboard", "dashboard.R"))
  jsonlite::write_json(list(dataset = "Unit-test fixture", mode = "synthetic_fixture", status = "complete",
                             assembly = "test", notes = "Temporary test data"), file.path(fixture, "status.json"),
                        auto_unbox = TRUE)
  check(identical(read_atac_results(fixture)$status$status, "Incomplete or invalid results bundle"),
        "Partial copies cannot be presented as complete result bundles")
  html <- as.character(atac_ui())
  check(grepl("Peak-calling method comparison", html) && grepl("No independent truth", html, ignore.case = TRUE),
        "UI exposes project purpose and truth-set limitation")
  shiny::testServer(atac_server(fixture), {
    session$setInputs(auto_refresh = FALSE, samples = c("RepA", "RepB"), callers = c("MACS3", "Genrich"),
                      overlap_sample = "RepA", width_sample = "RepA", download_table = "peak_metrics", refresh = 1)
    session$flushReact()
    check(nrow(tables()$peak_metrics) == 3, "Server loads observed rows")
    check(grepl("Synthetic validation data", output$status_banner$html), "Synthetic fixture provenance is explicit")
    session$setInputs(samples = "RepA", callers = "Genrich")
    session$flushReact()
    check(nrow(tables()$peak_metrics) == 1, "Reactive filters restrict the comparison")
    session$setInputs(samples = character())
    session$flushReact()
    check(nrow(tables()$peak_metrics) == 0, "Clearing a selection shows no selected rows")
    session$setInputs(samples = "RepA", callers = c("MACS3", "Genrich"))
    session$flushReact()
    check(is.list(output$counts_plot) && is.list(output$agreement_plot), "Charts render from validated measurements")
    check(is.list(output$fragment_plot), "Fragment distributions render from measured counts")
  })
  empty_directory <- tempfile("atac-empty-")
  shiny::testServer(atac_server(empty_directory), {
    session$setInputs(auto_refresh = FALSE, refresh = 1)
    session$flushReact()
    check(grepl("Ready for your first analysis", output$overview$html), "Server renders actionable empty state")
    check(!results()$has_results, "Empty server does not fabricate measurements")
  })
} else {
  cat("SKIP Shiny reactive tests: run scripts/install_dashboard.R first.\n")
}
# Only this freshly created temporary fixture directory is removed.
unlink(fixture, recursive = TRUE)
cat("Dashboard checks passed.\n")
