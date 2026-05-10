#!/usr/bin/env Rscript

# ============================================================
# Figure 2 v3 composer — aligned widths, restored Fig 2A/B style
# 图 2 v3 拼合：宽度对齐 + 恢复 Fig 2A/B 原版样式
# ============================================================
#
# Inputs / 输入
# - figures from spatiotemporal_v3 (Fig 2A count map, Fig 2B point map)
#   均含主图 (含海南/部分南海) + 鹰眼图 + 正确图例（颜色+形状对应）
# - figures from sankey_v3 (Fig 2C with bottom-5 collapsed to Others)
#
# Output / 输出
#   ../figures_v3/figure2_combined_aligned.{png,pdf,pptx}
#   ../figures_v3/figure2_panel_a.png  (copy with consistent name)
#   ../figures_v3/figure2_panel_b.png
#   ../figures_v3/figure2_panel_c.png
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
script_path <- get_script_path()
code_dir  <- if (dir.exists(script_path)) script_path else dirname(script_path)
task_root <- normalizePath(file.path(code_dir, ".."))
fig_v3    <- file.path(task_root, "figures_v3")
dir_create(fig_v3, recurse = TRUE)

img_a <- file.path(task_root, "spatiotemporal_v3", "figures",
                   "fig_sp01_province_new_record_count_map.png")
img_b <- file.path(task_root, "spatiotemporal_v3", "figures",
                   "fig_sp03_across_order_point_map.png")
img_c <- file.path(task_root, "sankey_v3", "figures",
                   "fig_ref01_sankey_order_province_year_en_compact_v3.png")
stopifnot(all(file.exists(c(img_a, img_b, img_c))))

# Copy convenient names into figures_v3
file.copy(img_a, file.path(fig_v3, "figure2_panel_a_count_map.png"), overwrite = TRUE)
file.copy(img_b, file.path(fig_v3, "figure2_panel_b_point_map.png"), overwrite = TRUE)
file.copy(img_c, file.path(fig_v3, "figure2_panel_c_sankey_topN.png"), overwrite = TRUE)
# also pdf if exists
for (suff in c(".pdf", ".pptx")) {
  for (s in c("a"="sp01_province_new_record_count_map",
              "b"="sp03_across_order_point_map")) {
    src <- file.path(task_root, "spatiotemporal_v3", "figures", paste0("fig_", s, suff))
    if (file.exists(src)) {
      panel <- if (s == "sp01_province_new_record_count_map") "a" else "b"
      tag   <- if (panel == "a") "count_map" else "point_map"
      dst <- file.path(fig_v3, paste0("figure2_panel_", panel, "_", tag, suff))
      file.copy(src, dst, overwrite = TRUE)
    }
  }
  src_c <- file.path(task_root, "sankey_v3", "figures",
                     paste0("fig_ref01_sankey_order_province_year_en_compact_v3", suff))
  if (file.exists(src_c)) file.copy(src_c, file.path(fig_v3,
                              paste0("figure2_panel_c_sankey_topN", suff)), overwrite = TRUE)
}

# ----- Determine common width for all 3 panels -----
# Strategy: render all three panels into a single image grid, with the
# top-row width (a + b side-by-side) equalling the bottom-row sankey width.
# 上行 (a + b) 宽度等于下行 sankey 宽度，三 panel 整体对齐。

w_combined_in <- 13.6      # total figure width in inches
half_w        <- w_combined_in / 2
top_h_in      <- 4.8       # height for top maps
bot_h_in      <- 5.4       # height for sankey
h_combined_in <- top_h_in + bot_h_in

# Read panels via magick → ggdraw
draw_panel_with_label <- function(path, lab) {
  ggdraw() + draw_image(path) +
    draw_label(lab, x = 0.005, y = 0.985, hjust = 0, vjust = 1,
               size = 16, fontface = "bold", colour = "#222")
}
p_a <- draw_panel_with_label(img_a, "(a)")
p_b <- draw_panel_with_label(img_b, "(b)")
p_c <- draw_panel_with_label(img_c, "(c)")

top_row <- plot_grid(p_a, p_b, ncol = 2, rel_widths = c(1, 1))
fig2 <- plot_grid(top_row, p_c, ncol = 1, rel_heights = c(top_h_in, bot_h_in))

# Save composite
ggsave(file.path(fig_v3, "figure2_combined_aligned.png"), fig2,
       width = w_combined_in, height = h_combined_in, dpi = 600, bg = "white")
ggsave(file.path(fig_v3, "figure2_combined_aligned.pdf"), fig2,
       width = w_combined_in, height = h_combined_in,
       device = grDevices::cairo_pdf, bg = "white")

# PPTX: embed the high-res composite PNG (raster) — per-panel editable
# PPTX is provided separately above for users to edit single panels.
ppt <- read_pptx()
ppt <- add_slide(ppt, layout = "Blank", master = "Office Theme")
ppt <- ph_with(ppt,
  external_img(file.path(fig_v3, "figure2_combined_aligned.png"),
               width = w_combined_in, height = h_combined_in),
  location = ph_location(left = 0, top = 0,
                          width = w_combined_in, height = h_combined_in))
print(ppt, target = file.path(fig_v3, "figure2_combined_aligned.pptx"))

cat("\nFigure 2 v3 composite saved to:\n  ", fig_v3, "\n", sep = "")
