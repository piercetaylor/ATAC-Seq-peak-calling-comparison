atac_colors <- c(MACS3 = "#007C83", Genrich = "#C66B15", HMMRATAC = "#7264A8")

atac_plot_style <- function(left = 10) {
  par(mar = c(4.5, left, 1.5, 1.2), bg = "#FFFFFF", fg = "#223B4B", col.axis = "#405867",
      col.lab = "#223B4B", family = "sans", las = 1, cex = 0.95, bty = "n")
}

atac_barplot <- function(data, column, label, multiplier = 1, fraction = FALSE) {
  shiny::validate(shiny::need(nrow(data) > 0L, "No measurements for this selection."))
  values <- data[[column]] * multiplier
  shiny::validate(shiny::need(any(is.finite(values)), "This measurement has not been reported."))
  labels <- if ("caller" %in% names(data)) paste(data$sample, data$caller, sep = " / ") else data$sample
  keep <- is.finite(values)
  values <- values[keep]
  labels <- labels[keep]
  colors <- if ("caller" %in% names(data)) unname(atac_colors[data$caller[keep]]) else rep("#007C83", sum(keep))
  colors[is.na(colors)] <- "#547080"
  ord <- rev(seq_along(values))
  values <- values[ord]
  labels <- labels[ord]
  colors <- colors[ord]
  atac_plot_style(left = min(17, max(8, max(nchar(labels)) * 0.43)))
  limit <- if (fraction) 100 else max(values, 1) * 1.22
  positions <- barplot(values, names.arg = labels, horiz = TRUE, col = colors, border = NA,
                      xlim = c(0, limit), xlab = label, axes = FALSE, cex.names = 0.85)
  axis(1, col = NA, col.ticks = "#CDD9DE", cex.axis = 0.9)
  text(pmin(values + limit * 0.018, limit * 0.91), positions,
       labels = if (fraction) sprintf("%.1f%%", values) else format(signif(values, 3), trim = TRUE, big.mark = ","),
       pos = 4, cex = 0.82, col = "#223B4B", xpd = TRUE)
}

atac_heatmap <- function(data, callers) {
  shiny::validate(shiny::need(nrow(data) > 0 && length(callers) > 1,
                            "Pairwise overlap is available after two callers complete for a sample."))
  values <- atac_overlap_matrix(data, callers)
  palette <- grDevices::colorRampPalette(c("#EDF5F4", "#75BCBA", "#00636B"))(101)
  n <- length(callers)
  atac_plot_style(left = 7)
  par(mar = c(5, 7, 1, 1))
  plot.new()
  plot.window(xlim = c(0.5, n + 0.5), ylim = c(0.5, n + 0.5), asp = 1)
  for (i in seq_len(n)) for (j in seq_len(n)) {
    value <- values[i, j]
    color <- if (is.na(value)) "#F2F4F4" else palette[round(value * 100) + 1L]
    rect(j - .48, n - i + .52, j + .48, n - i + 1.48, col = color, border = NA)
    label <- if (is.na(value)) "\u2014" else sprintf("%.3f", value)
    text(j, n - i + 1, label, col = if (!is.na(value) && value > .7) "#FFFFFF" else "#223B4B", cex = 1.05)
  }
  axis(1, at = seq_len(n), labels = callers, tick = FALSE)
  axis(2, at = seq_len(n), labels = rev(callers), tick = FALSE)
  mtext("Jaccard: 0 = no shared bases; 1 = identical covered bases", side = 1, line = 2.6, cex = .85)
}

atac_replicate_plot <- function(data) {
  shiny::validate(shiny::need(nrow(data) > 0L, "Replicate overlap is available after both samples complete."))
  data$sample <- paste(data$sample_a, data$sample_b, sep = " vs ")
  atac_barplot(data, "jaccard", "Jaccard overlap (%)", multiplier = 100, fraction = TRUE)
}

atac_distribution <- function(data, length_column, count_column, group_column, bin_width, x_label) {
  shiny::validate(shiny::need(nrow(data) > 0L, "No distribution measurements have been reported."))
  keep <- is.finite(data[[length_column]]) & is.finite(data[[count_column]])
  data <- data[keep, , drop = FALSE]
  shiny::validate(shiny::need(nrow(data) > 0L && sum(data[[count_column]]) > 0, "No measured intervals in this selection."))
  groups <- unique(data[[group_column]])
  bins <- floor(data[[length_column]] / bin_width) * bin_width
  curves <- lapply(groups, function(group) {
    keep <- data[[group_column]] == group
    counts <- tapply(data[[count_column]][keep], bins[keep], sum)
    # Include unoccupied bins so lines do not imply density through gaps.
    complete_bins <- seq(0, max(bins[keep]), by = bin_width)
    complete_counts <- numeric(length(complete_bins))
    complete_counts[match(as.numeric(names(counts)), complete_bins)] <- counts
    data.frame(x = complete_bins + bin_width / 2, y = complete_counts / sum(complete_counts) * 100)
  })
  colors <- if (group_column == "caller") unname(atac_colors[groups]) else rep(c("#007C83", "#7264A8", "#C66B15", "#547080"), length.out = length(groups))
  colors[is.na(colors)] <- "#547080"
  xmax <- max(data[[length_column]], bin_width)
  ymax <- max(unlist(lapply(curves, function(x) x$y)), na.rm = TRUE)
  atac_plot_style(left = 5)
  plot(NA, xlim = c(0, xmax + bin_width), ylim = c(0, max(ymax, 1) * 1.12), xlab = x_label,
       ylab = "Fraction (%)", xaxs = "i", yaxs = "i")
  for (i in seq_along(curves)) {
    curve <- curves[[i]]
    lines(curve$x, curve$y, col = colors[i], lwd = 2, type = "b", pch = 16, cex = .3)
  }
  legend("topright", legend = groups, col = colors, lwd = 2, bty = "n", cex = .85)
}
