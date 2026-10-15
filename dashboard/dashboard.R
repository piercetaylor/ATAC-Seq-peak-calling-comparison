atac_ui <- function() {
  shiny::fluidPage(
    tags$head(tags$title("ATAC-seq method comparison"),
              tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
              tags$link(rel = "stylesheet", type = "text/css", href = "dashboard.css")),
    tags$a(href = "#comparison-main", class = "skip-link", "Skip to comparison"),
    tags$header(class = "project-header",
      div(class = "header-inner",
        div(class = "project-mark", "ATAC", tags$span("seq")),
        div(class = "header-copy", h1("Peak-calling method comparison"),
            p("Human GM12878 Omni-ATAC \u00b7 two replicates \u00b7 three methods")),
        div(class = "header-tag", "Research workspace"))),
    div(class = "workspace", fluidRow(
      column(3, tags$aside(class = "controls", `aria-label` = "Comparison controls",
        h2("Compare results"),
        p(class = "muted", "Choose samples and methods to explore the same experiment from different views."),
        selectInput("samples", "Samples", choices = character(), multiple = TRUE),
        selectInput("callers", "Peak callers", choices = character(), multiple = TRUE),
        actionButton("reset_filters", "Select all", class = "btn-quiet"),
        tags$hr(),
        actionButton("refresh", "Refresh results", class = "btn-refresh"),
        checkboxInput("auto_refresh", "Check for updates every 30 seconds", value = TRUE),
        uiOutput("last_updated"),
        div(class = "sidebar-note", h3("A fair reading"),
          p("Peak count, FRiP, agreement, and resource use answer different questions. Read them together."),
          p("This comparison has no independent truth set and cannot establish a most accurate caller.")),
        div(class = "method-key", tags$span(class = "dot macs"), "MACS3", tags$br(),
            tags$span(class = "dot genrich"), "Genrich", tags$br(),
            tags$span(class = "dot hmm"), "HMMRATAC"))),
      column(9, tags$main(id = "comparison-main",
        uiOutput("status_banner"), uiOutput("data_issues"), uiOutput("summary"),
        tabsetPanel(id = "view", type = "tabs",
          tabPanel("Overview",
            uiOutput("overview"),
            div(class = "content-panel", h2("The comparison design"),
              div(class = "design-flow",
                div(tags$strong("One public experiment"), tags$span("GM12878 Omni-ATAC")),
                div(tags$strong("Matched preprocessing"), tags$span("One filtered alignment per sample")),
                div(tags$strong("Three peak callers"), tags$span("MACS3, Genrich, HMMRATAC"))),
              p("Call each replicate separately, then compare genomic coverage between methods and between replicates. Caller-specific models and thresholds are retained and recorded."),
              p(class = "caption", "HMMRATAC is run through the maintained MACS3 implementation. Different models can produce peaks with different widths, so base-pair overlap is shown alongside peak counts."))),
          tabPanel("Read quality",
            div(class = "content-panel", h2("Reads retained for peak calling"),
              p("Raw and retained read pairs describe library depth and filtering. These measurements are shared across callers."),
              fluidRow(column(6, h3("Raw pairs"), plotOutput("raw_plot", height = "310px")),
                       column(6, h3("Filtered pairs"), plotOutput("filtered_plot", height = "310px"))),
              fluidRow(column(6, h3("Duplicate fraction"), plotOutput("duplicate_plot", height = "310px")),
                       column(6, h3("Mitochondrial fraction"), plotOutput("mito_plot", height = "310px"))),
              h3("Fragment length distribution"),
              plotOutput("fragment_plot", height = "340px"),
              p(class = "caption", "Fragment curves show each sample's fragments in 20 bp bins. Duplicate and mitochondrial fractions use pairs after trimming, before pair filtering, including unmapped pairs. Either primary mate can flag a pair; the two counts can overlap."),
              div(class = "table-wrap", tableOutput("qc_table")))),
          tabPanel("Peak profiles",
            div(class = "content-panel", h2("Peak calls and genomic coverage"),
              p("A larger peak set may cover more accessible sequence, include broader intervals, or admit more background. Count alone does not measure quality."),
              fluidRow(column(6, h3("Number of peaks"), plotOutput("counts_plot", height = "350px")),
                       column(6, h3("Median peak width"), plotOutput("width_plot", height = "350px"))),
              fluidRow(column(6, h3("Covered bases"), plotOutput("coverage_plot", height = "350px")),
                       column(6, h3("Fraction of fragments in peaks"), plotOutput("frip_plot", height = "350px"))),
              h3("Peak width distribution"),
              selectInput("width_sample", "Sample for the distribution", choices = character()),
              plotOutput("peak_width_plot", height = "340px"),
              p(class = "caption", "Each line shows the fraction of a caller's peaks in 100 bp bins for the selected sample. Very wide intervals can stretch the horizontal axis; medians above retain the original units."),
              div(class = "interpretation", tags$strong("FRiP depends on the peak set."),
                  " Here it is the fraction of eligible paired-end fragments overlapping at least one peak from that caller. Wider or more numerous peaks can increase FRiP; a higher value is not evidence of greater accuracy."),
              atac_threshold_note(),
              div(class = "table-wrap", tableOutput("peak_table")))),
          tabPanel("Agreement",
            div(class = "content-panel", h2("Agreement between methods"),
              p("Compare the bases covered by two peak sets from the same sample. Jaccard is the number of shared bases divided by the number of bases in their union."),
              selectInput("overlap_sample", "Sample for the heatmap", choices = character()),
              plotOutput("agreement_plot", height = "370px"),
              p(class = "caption", "An em dash means not measured or undefined. Self-comparisons are omitted. Low agreement may reflect model and peak-width differences as well as signal sensitivity."),
              div(class = "table-wrap", tableOutput("overlap_table"))),
            div(class = "content-panel", h2("Agreement between replicates"),
              p("Compare the two samples within each caller. This is a descriptive overlap measure; it is not an IDR analysis or a reproducibility significance test."),
              plotOutput("replicate_plot", height = "340px"),
              div(class = "table-wrap", tableOutput("replicate_table")))),
          tabPanel("Resource use",
            div(class = "content-panel", h2("Time and memory per peak call"),
              p("Measured elapsed time and peak resident memory for the caller stage. Preprocessing, queue time, and data downloads are outside these measurements."),
              fluidRow(column(6, h3("Elapsed time"), plotOutput("time_plot", height = "350px")),
                       column(6, h3("Peak resident memory"), plotOutput("memory_plot", height = "350px"))),
              p(class = "caption", "Compare runs with the same hardware and resource allocation. Elapsed time varies with thread support and cluster load. Resident memory is not the requested SLURM memory allocation."),
              div(class = "table-wrap", tableOutput("runtime_table")))),
          tabPanel("Methods & evidence",
            atac_methods_ui(),
            div(class = "content-panel", h2("Download the evidence"),
              p("Table downloads include the current sample and caller selection. Values retain their original units: fractions from 0 to 1, elapsed seconds, and memory in KiB."),
              selectInput("download_table", "Results table", choices = c(
                "Peak metrics" = "peak_metrics", "Read quality" = "qc", "Method overlap" = "pairwise_overlap",
                "Replicate overlap" = "replicate_overlap", "Resource use" = "runtime",
                "Fragment lengths" = "fragment_lengths", "Peak widths" = "peak_widths")),
              downloadButton("download_results", "Download selected table"),
              downloadButton("download_status", "Download run metadata"),
              uiOutput("evidence_inventory")))
        ),
        tags$footer(class = "project-footer", "Public data. Explicit methods. Evidence before rankings.")
      ))
    ))
  )
}

atac_threshold_note <- function() {
  div(class = "interpretation", tags$strong("Caller thresholds differ."),
      " MACS3 uses q < 0.01. Genrich uses p < 0.01: its q-values are adjusted across every genome position, and at q < 0.01 (or 0.05) it reported zero peaks on these libraries. HMMRATAC uses its own model with no q cutoff. Genrich's looser cutoff likely contributes to its higher peak count, FRiP, and replicate agreement.")
}

atac_methods_ui <- function() {
  div(class = "content-panel methods", h2("What the methods measure"),
      h3("MACS3"), p("Models enrichment over genomic background. This workflow uses paired-end fragment mode (BAMPE) with q < 0.01."),
      tags$a(href = "https://macs3-project.github.io/MACS/docs/callpeak.html", target = "_blank", rel = "noopener", "MACS3 callpeak documentation"),
      h3("Genrich"), p("Tests genomic enrichment with an ATAC-seq mode that interprets cut sites. Its treatment of the signal differs from fragment-based callers. Run in ATAC mode at p < 0.01, its documented default; q cutoffs produced zero peaks here because Genrich adjusts across every genome position."),
      tags$a(href = "https://github.com/jsh58/Genrich", target = "_blank", rel = "noopener", "Genrich methods and options"),
      h3("HMMRATAC"), p("Uses fragment-length information and a hidden Markov model to identify accessible regions and their nucleosomal context. This project uses macs3 hmmratac."),
      tags$a(href = "https://macs3-project.github.io/MACS/docs/hmmratac.html", target = "_blank", rel = "noopener", "HMMRATAC in MACS3"),
      tags$hr(), h2("Literature guiding the comparison"),
      p(tags$a(href = "https://doi.org/10.1093/nargab/lqab101", target = "_blank", rel = "noopener",
               "Smith et al. (2021), PEPATAC: an optimized pipeline for ATAC-seq data analysis with serial alignments"),
        ". Direct precedent for comparing MACS2, Genrich, HMMRATAC, and other peak callers with interval Jaccard agreement."),
      p(tags$a(href = "https://doi.org/10.1093/nar/gkz533", target = "_blank", rel = "noopener",
               "Tarbell and Liu (2019), HMMRATAC: a Hidden Markov ModeleR for ATAC-seq"),
        ". Original method and comparison with MACS2 and F-Seq; this project uses the later MACS3 implementation."),
      p(tags$a(href = "https://link.springer.com/article/10.1186/s12864-021-08266-x", target = "_blank", rel = "noopener",
               "Zhang et al. (2022), Extensive evaluation of ATAC-seq protocols for native or formaldehyde-fixed nuclei"),
        ". This protocol and quality-control study reuses two GM12878 replicates from the original Omni-ATAC study. It shows why FRiP depends on the chosen peak set and sequencing depth; it is not a direct benchmark of these three callers."),
      h3("Scope of the evidence"),
      tags$ul(tags$li("Two replicates from one cell line support a focused case study, not a general ranking across tissues or protocols."),
              tags$li("Matched inputs reduce preprocessing differences; caller parameters and statistical models still differ."),
              tags$li("Peak counts, width, FRiP, and Jaccard describe output behavior. They do not estimate precision or recall without an independent reference."),
              tags$li("A small pilot or subsample can validate the workflow. Biological interpretation requires the intended analysis depth.")))
}

atac_server <- function(results_directory) {
  force(results_directory)
  function(input, output, session) {
    results <- reactive({
      input$refresh
      if (isTRUE(input$auto_refresh)) invalidateLater(30000, session)
      read_atac_results(results_directory)
    })
    known_choices <- reactiveValues(samples = NULL, callers = NULL)
    observeEvent(results(), {
      state <- results()
      previous_samples <- isolate(input$samples)
      previous_callers <- isolate(input$callers)
      updateSelectInput(session, "samples", choices = state$samples,
                        selected = if (!length(known_choices$samples)) state$samples else intersect(previous_samples, state$samples))
      updateSelectInput(session, "callers", choices = state$callers,
                        selected = if (!length(known_choices$callers)) state$callers else intersect(previous_callers, state$callers))
      known_choices$samples <- state$samples
      known_choices$callers <- state$callers
    })
    observeEvent(input$reset_filters, {
      updateSelectInput(session, "samples", selected = results()$samples)
      updateSelectInput(session, "callers", selected = results()$callers)
    })
    selected_samples <- reactive(if (is.null(input$samples)) character() else input$samples)
    selected_callers <- reactive(if (is.null(input$callers)) character() else input$callers)
    tables <- reactive(lapply(results()$tables, filter_atac_table, samples = selected_samples(), callers = selected_callers()))
    observeEvent(selected_samples(), {
      previous <- isolate(input$overlap_sample)
      choices <- selected_samples()
      updateSelectInput(session, "overlap_sample", choices = choices,
                        selected = if (length(previous) && previous %in% choices) previous else head(choices, 1))
      previous_width <- isolate(input$width_sample)
      updateSelectInput(session, "width_sample", choices = choices,
                        selected = if (length(previous_width) && previous_width %in% choices) previous_width else head(choices, 1))
    })
    output$last_updated <- renderUI({
      updated <- results()$last_update
      p(class = "last-updated", if (is.null(updated)) "No exported results yet." else paste("Files updated", format(updated, "%d %b %Y, %H:%M %Z")))
    })
    output$status_banner <- renderUI({
      state <- results()
      status <- state$status
      mode <- switch(status$mode, full = "Full dataset", synthetic_fixture = "Synthetic validation data; not biological results",
                     subsample_smoke = "Subsample smoke test; limited sequencing depth", status$mode)
      div(class = "status-banner", role = "status",
          div(tags$strong(status$dataset), tags$span(class = "run-badge", status$status)),
          p(paste("Analysis mode:", mode, " |  Assembly:", status$assembly)),
          if (nzchar(status$notes)) p(class = "status-notes", status$notes))
    })
    output$data_issues <- renderUI({
      issues <- results()$issues
      if (length(issues)) div(class = "data-warning", role = "alert", tags$strong("Some evidence files need attention"),
                              p("The affected tables are withheld so incomplete or invalid values are not plotted."),
                              tags$ul(lapply(issues, tags$li)))
    })
    output$summary <- renderUI({
      data <- tables()$peak_metrics
      card <- function(value, label) div(class = "summary-item", tags$strong(value), tags$span(label))
      div(class = "summary-rail",
          card(length(selected_samples()), "Samples selected"),
          card(length(selected_callers()), "Methods selected"),
          card(if (results()$has_results) nrow(data) else "\u2014", "Caller/sample results"),
          card(if (nrow(data) && any(!is.na(data$frip))) paste0(atac_number(median(data$frip, na.rm = TRUE) * 100, 1), "%") else "\u2014", "Median selected FRiP"))
    })
    output$overview <- renderUI({
      state <- results()
      if (!state$has_results) {
        div(class = "empty-state",
            div(class = "empty-symbol", `aria-hidden` = "true", "[  ]"),
            h2("Ready for your first analysis"),
            p("The public dataset and comparison are defined. No measured results have been loaded yet."),
            tags$ol(tags$li("Run the prepared SLURM workflow on Hellbender."),
                    tags$li("Copy the exported dashboard results folder to this project, or select its location with ATAC_RESULTS_DIR."),
                    tags$li("Choose Refresh results. The plots and downloads will appear as evidence files arrive.")),
            p(class = "caption", "No example values or simulated findings are shown."))
      } else {
        data <- tables()$peak_metrics
        findings <- atac_findings(tables())
        tagList(
          if (length(findings)) div(class = "content-panel", h2("Key findings"),
            tags$ul(class = "findings", lapply(findings, tags$li)),
            atac_threshold_note(),
            p(class = "caption", "Computed from the current selection. Agreement and FRiP describe output behavior, not accuracy.")),
          div(class = "content-panel", h2("Available evidence"),
            p("Each row is one sample analyzed by one caller. Use the tabs to inspect read quality, peak profiles, agreement, and resource use."),
            if (!nrow(data)) p(class = "inline-empty", "No peak calls match the current selection. Select a sample and a caller, or wait for peak metrics to be exported.") else div(class = "table-wrap", tableOutput("overview_table")),
            p(class = "caption", "Missing measurements remain unreported. A row in this table confirms that metrics were exported; the run status above reports overall completion.")))
      }
    })
    output$overview_table <- renderTable(atac_display_table(tables()$peak_metrics[c("sample", "caller", "n_peaks", "median_peak_width", "frip")]), striped = TRUE, bordered = FALSE, spacing = "m", na = "Not reported")
    for (item in list(c("peak_table", "peak_metrics"), c("qc_table", "qc"), c("overlap_table", "pairwise_overlap"),
                     c("replicate_table", "replicate_overlap"), c("runtime_table", "runtime"))) {
      local({
        output_name <- item[1]; table_name <- item[2]
        output[[output_name]] <- renderTable({
          data <- tables()[[table_name]]
          validate(need(nrow(data) > 0, "No rows available for this selection."))
          atac_display_table(data)
        }, striped = TRUE, bordered = FALSE, spacing = "m", na = "Not reported")
      })
    }
    output$raw_plot <- renderPlot(atac_barplot(tables()$qc, "raw_pairs", "Read pairs"), res = 110)
    output$filtered_plot <- renderPlot(atac_barplot(tables()$qc, "filtered_pairs", "Read pairs"), res = 110)
    output$duplicate_plot <- renderPlot(atac_barplot(tables()$qc, "duplicate_fraction", "Duplicate fraction (%)", 100, TRUE), res = 110)
    output$mito_plot <- renderPlot(atac_barplot(tables()$qc, "mitochondrial_fraction", "Mitochondrial fraction (%)", 100, TRUE), res = 110)
    output$fragment_plot <- renderPlot(atac_distribution(tables()$fragment_lengths, "length_bp", "fragments", "sample", 20, "Fragment length (bp)"), res = 110)
    output$counts_plot <- renderPlot(atac_barplot(tables()$peak_metrics, "n_peaks", "Peaks"), res = 110)
    output$width_plot <- renderPlot(atac_barplot(tables()$peak_metrics, "median_peak_width", "Base pairs"), res = 110)
    output$coverage_plot <- renderPlot(atac_barplot(tables()$peak_metrics, "total_peak_bp", "Megabases covered", 1e-6), res = 110)
    output$frip_plot <- renderPlot(atac_barplot(tables()$peak_metrics, "frip", "Fragments in peaks (%)", 100, TRUE), res = 110)
    output$peak_width_plot <- renderPlot({
      data <- tables()$peak_widths
      sample <- input$width_sample
      if (is.null(sample)) sample <- head(selected_samples(), 1)
      atac_distribution(data[data$sample %in% sample, , drop = FALSE], "width_bp", "peaks", "caller", 100, "Peak width (bp)")
    }, res = 110)
    output$agreement_plot <- renderPlot({
      data <- tables()$pairwise_overlap
      sample <- input$overlap_sample
      if (is.null(sample)) sample <- head(selected_samples(), 1)
      atac_heatmap(data[data$sample %in% sample, , drop = FALSE], selected_callers())
    }, res = 110)
    output$replicate_plot <- renderPlot(atac_replicate_plot(tables()$replicate_overlap), res = 110)
    output$time_plot <- renderPlot(atac_barplot(tables()$runtime, "elapsed_seconds", "Elapsed minutes", 1/60), res = 110)
    output$memory_plot <- renderPlot(atac_barplot(tables()$runtime, "max_rss_kb", "Peak resident memory (GiB)", 1/1024^2), res = 110)
    output$download_results <- downloadHandler(
      filename = function() paste0(input$download_table, "_selected.tsv"),
      content = function(file) {
        selected <- input$download_table
        req(selected %in% names(atac_schemas))
        write.table(tables()[[selected]], file, sep = "\t", row.names = FALSE, quote = FALSE, na = "NA")
      }, contentType = "text/tab-separated-values")
    output$download_status <- downloadHandler(filename = "status.json", content = function(file) {
      original <- file.path(results_directory, "status.json")
      if (file.exists(original)) file.copy(original, file, overwrite = TRUE) else {
        jsonlite::write_json(results()$status, file, auto_unbox = TRUE, pretty = TRUE)
      }
    }, contentType = "application/json")
    output$evidence_inventory <- renderUI({
      state <- results()
      div(class = "inventory", h3("Loaded files"),
          tags$ul(lapply(names(atac_schemas), function(name) {
            tags$li(tags$span(paste0(name, ".tsv")), tags$strong(if (state$available[[name]]) paste(nrow(state$tables[[name]]), "rows") else "Awaiting valid file"))
          })))
    })
  }
}
