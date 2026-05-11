#!/usr/bin/env Rscript

# ============================================================
# Compose manuscript Figure 3 — 3 directional scenarios
# 稿件 Figure 3 拼合：三种方案方向性比较
# ============================================================
#
# Layout (3×3):
#   ┌───────────────┬───────────────┬───────────────┐
#   │ S1 windrose   │ S2 windrose   │ S3 windrose   │  (centroid ref)
#   │ R+B           │ BOTW_clean    │ All seasons   │
#   ├───────────────┼───────────────┼───────────────┤
#   │ S1 windrose   │ S2 windrose   │ S3 windrose   │  (nearest edge ref)
#   ├───────────────┴───────────────┴───────────────┤
#   │  S3 per-order 4×4 facets (canonical, best cov)│
#   └───────────────────────────────────────────────┘
#
# Output / 输出
#   figures/figure3_directional_3scenarios_combined.{png,pdf,pptx}
# ============================================================

suppressPackageStartupMessages({
  library(magick); library(cowplot); library(ggplot2); library(officer); library(fs)
})

get_script_path <- function() {
  ca <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", ca, value = TRUE)
  if (length(fa) > 0) { c<-sub("^--file=","",fa[1]); if (file.exists(c)) return(normalizePath(c)) }
  normalizePath(getwd())
}
HERE <- get_script_path()
code_dir <- if (dir.exists(HERE)) HERE else dirname(HERE)
TASK_ROOT <- normalizePath(file.path(code_dir, ".."))
fig_d <- file.path(TASK_ROOT, "directional_v3_3scn", "figures")

# Trim white margins
trim_to_tmp <- function(src, name) {
  out <- file.path(fig_d, paste0("_trim_", name, ".png"))
  img <- magick::image_read(src) |> magick::image_trim(fuzz = 10)
  magick::image_write(img, out, format = "png", quality = 100, density = 600)
  list(path = out, info = magick::image_info(img))
}

src_paths <- list(
  s1_cen = file.path(fig_d, "scenario1_overall_windrose_centroid.png"),
  s2_cen = file.path(fig_d, "scenario2_overall_windrose_centroid.png"),
  s3_cen = file.path(fig_d, "scenario3_overall_windrose_centroid.png"),
  s1_edg = file.path(fig_d, "scenario1_overall_windrose_nearest_edge.png"),
  s2_edg = file.path(fig_d, "scenario2_overall_windrose_nearest_edge.png"),
  s3_edg = file.path(fig_d, "scenario3_overall_windrose_nearest_edge.png"),
  s3_fac = file.path(fig_d, "scenario3_order_windrose_facets_centroid.png")
)
trims <- lapply(names(src_paths), function(n) trim_to_tmp(src_paths[[n]], n))
names(trims) <- names(src_paths)

draw_labeled <- function(path, label, label_size = 16) {
  ggdraw() + draw_image(path) +
    draw_label(label, x = 0.012, y = 0.985, hjust = 0, vjust = 1,
               size = label_size, fontface = "bold", colour = "#222")
}

p_a <- draw_labeled(trims$s1_cen$path, "(a) Scn1 R+B · centroid")
p_b <- draw_labeled(trims$s2_cen$path, "(b) Scn2 BOTW_clean · centroid")
p_c <- draw_labeled(trims$s3_cen$path, "(c) Scn3 All seasons · centroid")
p_d <- draw_labeled(trims$s1_edg$path, "(d) Scn1 R+B · nearest edge")
p_e <- draw_labeled(trims$s2_edg$path, "(e) Scn2 BOTW_clean · nearest edge")
p_f <- draw_labeled(trims$s3_edg$path, "(f) Scn3 All seasons · nearest edge")
p_g <- draw_labeled(trims$s3_fac$path, "(g) Scn3 All seasons — per-order facets (top 16)")

# Width budget: 13.6 inch; each top-row panel ~4.4" × (own aspect)
w_combined <- 13.6
gap <- 0.10
panel_w <- (w_combined - 2 * gap) / 3
# heights based on aspect ratios
ar_a <- trims$s1_cen$info$height / trims$s1_cen$info$width
top_h <- panel_w * ar_a + 0.1
ar_g <- trims$s3_fac$info$height / trims$s3_fac$info$width
fac_h <- w_combined * ar_g

# Top rows (centroid + nearest edge) using plot_grid
row1 <- plot_grid(p_a, NULL, p_b, NULL, p_c, ncol = 5,
                   rel_widths = c(1, gap/panel_w, 1, gap/panel_w, 1),
                   align = "h", axis = "tblr")
row2 <- plot_grid(p_d, NULL, p_e, NULL, p_f, ncol = 5,
                   rel_widths = c(1, gap/panel_w, 1, gap/panel_w, 1),
                   align = "h", axis = "tblr")
fig3 <- plot_grid(row1, NULL, row2, NULL, p_g, ncol = 1,
                   rel_heights = c(top_h, gap, top_h, gap, fac_h))
h_combined <- 2 * top_h + 2 * gap + fac_h

out_png <- file.path(fig_d, "figure3_directional_3scenarios_combined.png")
out_pdf <- file.path(fig_d, "figure3_directional_3scenarios_combined.pdf")
out_ppt <- file.path(fig_d, "figure3_directional_3scenarios_combined.pptx")
ggsave(out_png, fig3, width = w_combined, height = h_combined, dpi = 600, bg = "white")
ggsave(out_pdf, fig3, width = w_combined, height = h_combined,
       device = grDevices::cairo_pdf, bg = "white")
ppt <- read_pptx()
ppt <- add_slide(ppt, layout = "Blank", master = "Office Theme")
ppt <- ph_with(ppt, external_img(out_png, width = w_combined, height = h_combined),
               location = ph_location(left = 0, top = 0,
                                       width = w_combined, height = h_combined))
print(ppt, target = out_ppt)
cat("\n✓ Figure 3 composite written:\n  ", out_png, "\n", sep = "")
