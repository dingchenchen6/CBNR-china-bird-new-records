#!/usr/bin/env Rscript

# ============================================================
# Technical-pipeline flowchart + Fig 1 trim (v3)
# 技术路线流程图 + Fig 1 裁边
# ============================================================
#
# Output / 输出
#   ../figures_v3/figure_flowchart_pipeline.{png,pdf,svg}
#   ../figures_v3/figure1_phylogeny_trimmed.{png,pdf,pptx}
# ============================================================

suppressPackageStartupMessages({
  library(DiagrammeR); library(DiagrammeRsvg); library(rsvg)
  library(magick); library(officer); library(fs)
})

get_script_path <- function() {
  ca <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", ca, value = TRUE)
  if (length(fa) > 0) {
    cand <- sub("^--file=", "", fa[1])
    if (file.exists(cand)) return(normalizePath(cand))
  }
  normalizePath(getwd())
}
script_path <- get_script_path()
code_dir  <- if (dir.exists(script_path)) script_path else dirname(script_path)
task_root <- normalizePath(file.path(code_dir, ".."))
fig_v3    <- file.path(task_root, "figures_v3")
dir_create(fig_v3, recurse = TRUE)

# --------------------------------------------------------------------
# 1. Technical pipeline flowchart
#    技术路线图：原始文献 → LLM 抽取 → 人工校核 → 分类/坐标/重复校正
#                → canonical 数据 → 5 大下游分析 → 5 张稿件图
# --------------------------------------------------------------------
graph_def <- "
digraph CBNR {
  graph [layout = dot, rankdir = TB, fontname = 'Helvetica', bgcolor='white',
         splines=ortho, nodesep=0.45, ranksep=0.55]
  node  [fontname = 'Helvetica', fontsize = 11, style = 'filled,rounded',
         shape = box, penwidth = 1.1, color = '#444444', height=0.40]
  edge  [fontname = 'Helvetica', fontsize = 9, color = '#666666',
         arrowsize = 0.7, penwidth = 1.0]

  /* === Stage 1: Source acquisition === */
  subgraph cluster_src {
    label = '1. Literature acquisition / 文献获取'
    style = 'rounded,filled'; fillcolor = '#F2F7FB'; color = '#7AA8D6'
    fontsize = 12; fontcolor = '#1F4E79'
    cnki   [label = 'CNKI search\\n(Chinese)', fillcolor = '#FFFFFF']
    gsch   [label = 'Google Scholar\\n(English)', fillcolor = '#FFFFFF']
    pdfs   [label = '764 candidate PDFs', fillcolor = '#D9E7F4']
  }
  cnki -> pdfs
  gsch -> pdfs

  /* === Stage 2: Extraction === */
  subgraph cluster_extract {
    label = '2. LLM-assisted extraction / LLM 辅助信息抽取'
    style = 'rounded,filled'; fillcolor = '#FFF7E6'; color = '#E0A958'
    fontsize = 12; fontcolor = '#8C5A1F'
    llm    [label = 'GPT-class LLM\\n+ schema-constrained\\nprompt', fillcolor = '#FFFFFF']
    calib  [label = '100-paper calibration\\nbenchmark (>=98% acc.)', fillcolor = '#FFFFFF']
    raw    [label = 'Raw extracted table\\n(1,025 rows × 38 fields)', fillcolor = '#FFE5B5']
  }
  pdfs  -> llm
  llm   -> raw
  llm   -> calib [style=dashed]
  calib -> llm   [style=dashed, label='prompt iteration']

  /* === Stage 3: Cleaning === */
  subgraph cluster_clean {
    label = '3. Quality control & taxonomic harmonisation / 质控与分类规范化'
    style = 'rounded,filled'; fillcolor = '#F0F7F0'; color = '#7AB07A'
    fontsize = 12; fontcolor = '#2E5E2E'
    tax    [label = 'Taxonomic harmonisation\\n(CoL China 2025 + Zheng 2023)',
            fillcolor = '#FFFFFF']
    coord  [label = 'Coordinate plausibility\\n(lat/lon range, lon=lat flag)',
            fillcolor = '#FFFFFF']
    dedup  [label = 'Species-province dedup\\n(earliest publication year)',
            fillcolor = '#FFFFFF']
    yrflag [label = 'Year scope flag\\n(year_in_scope = year >= 2000)',
            fillcolor = '#FFFFFF']
    canon  [label = 'CANONICAL ANALYTICAL TABLE\\n1,020 events · 564 species\\n23 orders · 33 provinces',
            fillcolor = '#C8E6C9', fontsize=12, style='filled,rounded,bold']
  }
  raw    -> tax    -> dedup
  raw    -> coord
  raw    -> yrflag
  tax    -> canon
  coord  -> canon
  dedup  -> canon
  yrflag -> canon

  /* === Stage 4: Downstream analyses === */
  subgraph cluster_ana {
    label = '4. Downstream analyses / 下游分析模块'
    style = 'rounded,filled'; fillcolor = '#FBF1F4'; color = '#D88AAD'
    fontsize = 12; fontcolor = '#6E2D54'
    phy    [label = 'Phylogenetic\\ncoverage\\n(McTavish 2025)', fillcolor = '#FFFFFF']
    sp     [label = 'Spatiotemporal\\npatterns\\n(sf + Albers EA)', fillcolor = '#FFFFFF']
    sk     [label = 'Sankey flow\\nOrder–Province–Year\\n(ggalluvial)', fillcolor = '#FFFFFF']
    qc     [label = 'QC\\nbefore/after\\ndiagnostics', fillcolor = '#FFFFFF']
    ord    [label = 'Order-level\\ncoverage table\\n(Wilson 95% CI)', fillcolor = '#FFFFFF']
  }
  canon -> phy
  canon -> sp
  canon -> sk
  canon -> qc
  canon -> ord

  /* === Stage 5: Outputs === */
  subgraph cluster_out {
    label = '5. Manuscript outputs / 稿件产出'
    style = 'rounded,filled'; fillcolor = '#F4EEFA'; color = '#9966CC'
    fontsize = 12; fontcolor = '#552E80'
    f1     [label = 'Figure 1\\nCircular phylogeny',  fillcolor = '#E1D5F0']
    f2     [label = 'Figure 2\\nMap+Map+Sankey\\n(combined)',
            fillcolor = '#E1D5F0']
    f5     [label = 'Figure 5\\nQC validation',        fillcolor = '#E1D5F0']
    t23    [label = 'Tables 2 & 3\\n(metadata, order)', fillcolor = '#E1D5F0']
  }
  phy -> f1
  sp  -> f2
  sk  -> f2
  qc  -> f5
  ord -> t23
}
"

g <- DiagrammeR::grViz(graph_def)
svg_str <- DiagrammeRsvg::export_svg(g)
writeLines(svg_str, file.path(fig_v3, "figure_flowchart_pipeline.svg"))
rsvg::rsvg_png(charToRaw(svg_str),
               file.path(fig_v3, "figure_flowchart_pipeline.png"),
               width = 1800)
rsvg::rsvg_pdf(charToRaw(svg_str),
               file.path(fig_v3, "figure_flowchart_pipeline.pdf"))
# PPTX: embed PNG
ppt <- read_pptx()
ppt <- add_slide(ppt, layout = "Blank", master = "Office Theme")
ppt <- ph_with(ppt,
  external_img(file.path(fig_v3, "figure_flowchart_pipeline.png"),
               width = 13, height = 9),
  location = ph_location(left = 0, top = 0, width = 13, height = 9))
print(ppt, target = file.path(fig_v3, "figure_flowchart_pipeline.pptx"))
message("✓ Flowchart written: PNG + PDF + SVG + PPTX")

# --------------------------------------------------------------------
# 2. Trim Fig 1 phylogeny white margins
# --------------------------------------------------------------------
fig1_src <- file.path(task_root, "phylogeny_v3", "figures",
                      "fig_phy01_mctavish_bird_new_records_phylogeny.png")
if (file.exists(fig1_src)) {
  img1 <- magick::image_read(fig1_src) |>
    magick::image_trim(fuzz = 5) |>
    magick::image_border("white", "20x20")
  info1 <- magick::image_info(img1)
  w1 <- 13.6; h1 <- info1$height / info1$width * w1
  png1 <- file.path(fig_v3, "figure1_phylogeny_trimmed.png")
  pdf1 <- file.path(fig_v3, "figure1_phylogeny_trimmed.pdf")
  ppt1 <- file.path(fig_v3, "figure1_phylogeny_trimmed.pptx")
  magick::image_write(img1, png1, format = "png", quality = 100, density = 600)
  magick::image_write(img1, pdf1, format = "pdf")
  ppt <- read_pptx()
  ppt <- add_slide(ppt, layout = "Blank", master = "Office Theme")
  ppt <- ph_with(ppt, external_img(png1, width = w1, height = h1),
                 location = ph_location(left = 0, top = 0,
                                         width = w1, height = h1))
  print(ppt, target = ppt1)
  message("✓ Fig 1 trimmed: PNG + PDF + PPTX (raster)")
} else {
  warning("Phylogeny PNG not found: ", fig1_src)
}
cat("\nDone — outputs in ", fig_v3, "\n")
