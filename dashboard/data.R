# Data contract and validation are separate from Shiny for independent checks.
atac_schemas <- list(
  peak_metrics = list(
    ids = c("sample", "caller"),
    numeric = c("n_peaks", "total_peak_bp", "median_peak_width", "frip", "fragments"),
    fractions = "frip", counts = c("n_peaks", "total_peak_bp", "fragments")),
  pairwise_overlap = list(
    ids = c("sample", "caller_a", "caller_b"),
    numeric = c("intersection_bp", "union_bp", "jaccard"),
    fractions = "jaccard", counts = c("intersection_bp", "union_bp")),
  replicate_overlap = list(
    ids = c("caller", "sample_a", "sample_b"),
    numeric = c("intersection_bp", "union_bp", "jaccard"),
    fractions = "jaccard", counts = c("intersection_bp", "union_bp")),
  qc = list(
    ids = "sample", numeric = c("raw_pairs", "filtered_pairs", "duplicate_fraction", "mitochondrial_fraction"),
    fractions = c("duplicate_fraction", "mitochondrial_fraction"),
    counts = c("raw_pairs", "filtered_pairs")),
  runtime = list(ids = c("sample", "caller"), numeric = c("elapsed_seconds", "max_rss_kb"),
                 fractions = character(), counts = character()),
  fragment_lengths = list(ids = "sample", keys = c("sample", "length_bp"),
                          numeric = c("length_bp", "fragments"), fractions = character(),
                          counts = c("length_bp", "fragments")),
  peak_widths = list(ids = c("sample", "caller"), keys = c("sample", "caller", "width_bp"),
                     numeric = c("width_bp", "peaks"), fractions = character(),
                     counts = c("width_bp", "peaks"))
)

empty_atac_table <- function(name) {
  schema <- atac_schemas[[name]]
  result <- as.data.frame(setNames(rep(list(character()), length(schema$ids)), schema$ids),
                          stringsAsFactors = FALSE)
  for (column in schema$numeric) result[[column]] <- numeric()
  result
}

read_atac_table <- function(path, name) {
  empty <- empty_atac_table(name)
  if (!file.exists(path)) return(list(data = empty, issue = NULL, available = FALSE))
  tryCatch({
    schema <- atac_schemas[[name]]
    data <- read.delim(path, check.names = FALSE, stringsAsFactors = FALSE,
                       colClasses = "character", na.strings = c("NA", "", "NaN"),
                       quote = "", comment.char = "", fill = FALSE)
    required <- c(schema$ids, schema$numeric)
    missing <- setdiff(required, names(data))
    if (length(missing)) stop("missing columns: ", paste(missing, collapse = ", "))
    if (anyDuplicated(names(data))) stop("duplicate column names")
    for (column in schema$ids) {
      if (anyNA(data[[column]]) || any(!nzchar(trimws(data[[column]])))) {
        stop("missing identifier in ", column)
      }
    }
    keys <- if (is.null(schema$keys)) schema$ids else schema$keys
    if (anyDuplicated(data[keys])) stop("duplicate sample/caller keys")
    for (column in schema$numeric) {
      parsed <- suppressWarnings(as.numeric(data[[column]]))
      if (any(!is.na(data[[column]]) & (is.na(parsed) | !is.finite(parsed)))) {
        stop("invalid numeric value in ", column)
      }
      if (any(parsed < 0, na.rm = TRUE)) stop("negative value in ", column)
      data[[column]] <- parsed
    }
    for (column in schema$fractions) {
      if (any(data[[column]] > 1, na.rm = TRUE)) stop(column, " must be between 0 and 1")
    }
    for (column in schema$counts) {
      if (any(data[[column]] != floor(data[[column]]), na.rm = TRUE)) {
        stop("non-integer count in ", column)
      }
    }
    if (name %in% c("pairwise_overlap", "replicate_overlap")) {
      if (any(data$intersection_bp > data$union_bp, na.rm = TRUE)) {
        stop("intersection exceeds union")
      }
      expected <- data$intersection_bp / data$union_bp
      check <- is.finite(expected) & !is.na(data$jaccard)
      if (any(abs(expected[check] - data$jaccard[check]) > 1e-5)) {
        stop("Jaccard values disagree with intersection / union")
      }
    }
    if (name == "qc" && any(data$filtered_pairs > data$raw_pairs, na.rm = TRUE)) {
      stop("filtered pairs exceed raw pairs")
    }
    list(data = data, issue = NULL, available = TRUE)
  }, error = function(e) {
    list(data = empty, issue = paste0(basename(path), ": ", conditionMessage(e)), available = FALSE)
  })
}

read_atac_results <- function(directory) {
  loaded <- lapply(names(atac_schemas), function(name) {
    read_atac_table(file.path(directory, paste0(name, ".tsv")), name)
  })
  names(loaded) <- names(atac_schemas)
  status <- list(dataset = "GM12878 Omni-ATAC", mode = "Not run", status = "Awaiting results",
                 assembly = "Not reported", notes = "")
  issues <- unlist(lapply(loaded, `[[`, "issue"), use.names = FALSE)
  status_file <- file.path(directory, "status.json")
  if (file.exists(status_file)) {
    metadata <- tryCatch(jsonlite::fromJSON(status_file, simplifyVector = TRUE),
                         error = function(e) e)
    if (inherits(metadata, "error") || !is.list(metadata)) {
      issues <- c(issues, "status.json: metadata could not be read")
    } else {
      for (key in intersect(names(status), names(metadata))) {
        value <- unlist(metadata[[key]], use.names = FALSE)
        if (length(value)) status[[key]] <- paste(as.character(value), collapse = " ")
      }
    }
  }
  data <- lapply(loaded, `[[`, "data")
  has_results <- any(vapply(data, nrow, integer(1)) > 0L)
  if (identical(status$status, "complete")) {
    required_tables <- c("peak_metrics", "pairwise_overlap", "replicate_overlap", "qc", "runtime")
    absent <- required_tables[!vapply(loaded[required_tables], `[[`, logical(1), "available")]
    if (length(absent)) issues <- c(issues, paste("Completed run is missing valid tables:", paste(absent, collapse = ", ")))
    if (length(issues)) status$status <- "Incomplete or invalid results bundle"
  }
  if (has_results && !file.exists(status_file)) {
    status$status <- "Run metadata unavailable"
    status$mode <- "Not reported"
    issues <- c(issues, "status.json is missing; run mode and completion cannot be verified")
  }
  samples <- sort(unique(c(data$peak_metrics$sample, data$qc$sample, data$runtime$sample,
                            data$pairwise_overlap$sample,
                            data$replicate_overlap$sample_a, data$replicate_overlap$sample_b)))
  callers <- sort(unique(c(data$peak_metrics$caller, data$runtime$caller,
                            data$pairwise_overlap$caller_a, data$pairwise_overlap$caller_b,
                            data$replicate_overlap$caller)))
  known <- c("MACS3", "Genrich", "HMMRATAC")
  callers <- c(intersect(known, callers), setdiff(callers, known))
  timestamps <- file.info(file.path(directory, c(paste0(names(atac_schemas), ".tsv"), "status.json")))$mtime
  last_update <- if (any(!is.na(timestamps))) max(timestamps, na.rm = TRUE) else NULL
  list(tables = data, status = status, issues = issues, samples = samples, callers = callers,
       available = vapply(loaded, `[[`, logical(1), "available"), last_update = last_update,
       has_results = has_results, directory = directory)
}

filter_atac_table <- function(data, samples, callers) {
  for (column in intersect(c("sample", "sample_a", "sample_b"), names(data))) {
    data <- data[data[[column]] %in% samples, , drop = FALSE]
  }
  for (column in intersect(c("caller", "caller_a", "caller_b"), names(data))) {
    data <- data[data[[column]] %in% callers, , drop = FALSE]
  }
  data
}

atac_overlap_matrix <- function(data, callers) {
  result <- matrix(NA_real_, length(callers), length(callers), dimnames = list(callers, callers))
  # Diagonal cells are intentionally unmeasured: a zero-peak set has no defined self Jaccard.
  for (i in seq_len(nrow(data))) {
    a <- data$caller_a[i]
    b <- data$caller_b[i]
    if (a %in% callers && b %in% callers) {
      result[a, b] <- result[b, a] <- data$jaccard[i]
    }
  }
  result
}

atac_number <- function(x, digits = 0) {
  ifelse(is.na(x), "Not reported", formatC(x, format = "f", digits = digits, big.mark = ","))
}

atac_display_table <- function(data) {
  for (column in intersect(c("frip", "duplicate_fraction", "mitochondrial_fraction"), names(data))) {
    data[[column]] <- ifelse(is.na(data[[column]]), "Not reported", sprintf("%.1f%%", data[[column]] * 100))
  }
  for (column in names(data)) {
    if (is.numeric(data[[column]])) {
      digits <- if (column %in% c("jaccard")) 3 else if (column == "elapsed_seconds") 1 else 0
      data[[column]] <- atac_number(data[[column]], digits)
    }
  }
  names(data) <- gsub("_", " ", names(data))
  data
}
