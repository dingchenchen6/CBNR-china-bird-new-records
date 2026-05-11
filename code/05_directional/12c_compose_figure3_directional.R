#!/usr/bin/env Rscript

# ============================================================
# Compose manuscript Figure 3 — directional patterns
# 拼合稿件 Figure 3：方向性格局
# ============================================================
#
# Layout (mirrors Fig 2 composite):
#   ┌──────────────────────────┬──────────────────────────┐
#   │ (a) Overall windrose     │ (b) Overall windrose     │
#   │     centroid-based       │     nearest-edge based   │
#   ├──────────────────────────┴──────────────────────────┤
#   │ (c) Per-order 4×4 windrose facets (centroid)        │
#   └──────────────────────────────────────────────────────┘
#
# Output / 输出
#   ../directional_v3/figures/figure3_directional_combined.{png,pdf,pptx}
# ============================================================

suppressPackageStartupMessages({
  library(magick); library(cowplot); library(ggplot2); library(officer); library(fs)
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
HERE <- get_script_path()
code_dir <- if (dir.exists(HERE)) HERE else dirname(HERE)
TASK_ROOT <- normalizePath(file.path(code_dir, ".."))
fig_d <- file.path(TASK_ROOT, "directional_v3", "figures")

img_a <- file.path(fig_d, "overall_direction_windrose_centroid.png")
img_b <- file.path(fig_d, "overall_direction_windrose_nearest_edge.png")
img_c <- file.path(fig_d, "order_direction_windrose_facets_centroid.png")
stopifnot(all(file.exists(c(img_a, img_b, img_c))))

# Trim white margins
trim_to_tmp <- function(src, name) {
  out <- file.path(fig_d, paste0("_trim_", name, ".png"))
  img <- magick::image_read(src) |> magick::image_trim(fuzz = 10)
  magick::image_write(img, out, format = "png", quality = 100, density = 600)
  list(path = out, info = magick::image_info(img))
}
ta <- trim_to_tmp(img_a, "a")
tb <- trim_to_tmp(img_b, "b")
tc <- trim_to_tmp(img_c, "c")

w_combined <- 13.6
half_w     <- (w_combined - 0.15) / 2
gap_in     <- 0.15
ar_a <- ta$info$height / ta$info$width
ar_b <- tb$info$height / tb$info$width
top_h <- max(half_w * ar_a, half_w * ar_b)
ar_c <- tc$info$height / tc$info$width
bot_h <- w_combined * ar_c
h_combined <- top_h + gap_in + bot_h

draw_panel_with_label <- function(path, lab) {
  ggdraw() + draw_image(path) +
    draw_label(lab, x = 0.005, y = 0.985, hjust = 0, vjust = 1,
               size = 16, fontface = "bold", colour = "#222")
}
p_a <- draw_panel_with_label(ta$path, "(a)")
p_b <- draw_panel_with_label(tb$path, "(b)")
p_c <- draw_panel_with_label(tc$path, "(c)")

top_row <- plot_grid(p_a, p_b, ncol = 2, rel_widths = c(1, 1),
                     align = "h", axis = "tblr")
fig3 <- plot_grid(top_row, NULL, p_c, ncol = 1,
                  rel_heights = c(top_h, gap_in, bot_h))

ggsave(file.path(fig_d, "figure3_directional_combined.png"), fig3,
       width = w_combined, height = h_combined, dpi = 600, bg = "white")
ggsave(file.path(fig_d, "figure3_directional_combined.pdf"), fig3,
       width = w_combined, height = h_combined,
       device = grDevices::cairo_pdf, bg = "white")

ppt <- read_pptx()
ppt <- add_slide(ppt, layout = "Blank", master = "Office Theme")
ppt <- ph_with(ppt,
  external_img(file.path(fig_d, "figure3_directional_combined.png"),
               width = w_combined, height = h_combined),
  location = ph_location(left = 0, top = 0,
                          width = w_combined, height = h_combined))
print(ppt, target = file.path(fig_d, "figure3_directional_combined.pptx"))

cat("\n✓ Figure 3 composite saved to:\n  ", fig_d, "\n", sep = "")
