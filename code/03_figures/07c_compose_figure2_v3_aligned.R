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

# ----- Trim each panel's white margins for tighter composition -----
# 用 magick::image_trim 先剔除每张子图四周白边，再做拼合，便于：
# (1) (a)(b) 拉近至几乎无间距；(2) sankey (c) 内容宽度与 (a)+(b) 严格对齐。
trim_to_tmp <- function(src, name) {
  out <- file.path(fig_v3, paste0("_trim_", name, ".png"))
  img <- magick::image_read(src) |> magick::image_trim(fuzz = 10)
  magick::image_write(img, out, format = "png", quality = 100, density = 600)
  list(path = out, info = magick::image_info(img))
}
ta <- trim_to_tmp(img_a, "a_count")   # count map (was a)
tb <- trim_to_tmp(img_b, "b_point")   # point map (was b)
tc <- trim_to_tmp(img_c, "c_sankey")  # sankey

# ----- Layout config -----
# Swap requested by user: point map → LEFT and labelled (a);
#                         count map → RIGHT and labelled (b).
# 用户要求互换：点分布图（原 b）置左侧并标 (a)；计数地图（原 a）置右侧并标 (b)。
left_panel  <- tb   # point map → new (a)
right_panel <- ta   # count map → new (b)
sankey      <- tc

w_combined_in <- 13.6
half_w        <- w_combined_in / 2
ar_left   <- left_panel$info$height  / left_panel$info$width
ar_right  <- right_panel$info$height / right_panel$info$width
top_h_in  <- max(half_w * ar_left, half_w * ar_right)
ar_sankey <- sankey$info$height / sankey$info$width
bot_h_in  <- w_combined_in * ar_sankey
h_combined_in <- top_h_in + bot_h_in

# Read panels via magick → ggdraw with tracked labels
draw_panel_with_label <- function(path, lab) {
  ggdraw() + draw_image(path) +
    draw_label(lab, x = 0.005, y = 0.985, hjust = 0, vjust = 1,
               size = 16, fontface = "bold", colour = "#222")
}
p_a <- draw_panel_with_label(left_panel$path,  "(a)")
p_b <- draw_panel_with_label(right_panel$path, "(b)")
p_c <- draw_panel_with_label(sankey$path,      "(c)")

# Tighter top row (no extra inter-panel gap), aligned to bottom sankey width
top_row <- plot_grid(p_a, p_b, ncol = 2, rel_widths = c(1, 1),
                      align = "h", axis = "tblr")
fig2 <- plot_grid(top_row, p_c, ncol = 1,
                   rel_heights = c(top_h_in, bot_h_in),
                   align = "v", axis = "lr")

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
